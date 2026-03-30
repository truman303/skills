# Architecture Patterns Reference

## Table of Contents

- [Feature-Based Project Structure](#feature-based-project-structure)
- [CQRS with MediatR](#cqrs-with-mediatr)
- [Domain Modeling](#domain-modeling)
- [ErrorOr Pattern](#erroror-pattern)
- [DependencyInjection Per Feature](#dependencyinjection-per-feature)
- [Error Handling Philosophy](#error-handling-philosophy)
- [Datastar Guidelines](#the-tao-of-datastar)

## Feature-Based Project Structure

Organize code by feature, not by technical concern:

```
MyApp/
├── Features/
│   ├── Shared/
│   │   ├── Database/
│   │   │   ├── AppDbContext.cs
│   │   │   └── Migrations/
│   │   ├── Exceptions/
│   │   │   └── GlobalExceptionHandlerMiddleware.cs
│   │   ├── Extensions/
│   │   │   └── RazorPageExtensions.cs
│   │   ├── Models/
│   │   │   ├── Entity.cs
│   │   │   ├── AggregateRoot.cs
│   │   │   ├── ValueObject.cs
│   │   │   ├── IDomainEvent.cs
│   │   │   └── IHasDomainEvents.cs
│   │   ├── Services/
│   │   │   ├── RazorPartialRenderer.cs
│   │   │   └── IClock.cs
│   │   └── DependencyInjection.cs
│   │
│   ├── Items/                          # Feature folder
│   │   ├── Commands/
│   │   │   ├── CreateItemCommand.cs    # Command + handler in same file
│   │   │   ├── UpdateItemCommand.cs
│   │   │   └── DeleteItemCommand.cs
│   │   ├── Queries/
│   │   │   ├── GetItemsQuery.cs        # Query + handler in same file
│   │   │   └── GetItemByIdQuery.cs
│   │   ├── Models/
│   │   │   └── Item.cs                 # Aggregate root + ID + errors + DTOs + repo + EF config
│   │   └── DependencyInjection.cs
│   │
│   └── OtherFeature/
│       └── ...
│
├── Pages/
│   ├── Shared/
│   │   ├── _Layout.cshtml
│   │   ├── _Message.cshtml             # Inline message partial
│   │   └── _Toast.cshtml               # Toast notification partial
│   ├── Items/
│   │   ├── Index.cshtml
│   │   ├── Index.cshtml.cs
│   │   ├── _ItemsTable.cshtml          # Table fragment for SSE updates
│   │   ├── Create.cshtml
│   │   ├── Create.cshtml.cs
│   │   ├── Edit.cshtml
│   │   ├── Edit.cshtml.cs
│   │   ├── Details.cshtml
│   │   └── Details.cshtml.cs
│   └── _ViewImports.cshtml
│
├── wwwroot/
├── Program.cs
└── MyApp.csproj
```

**Namespace convention:** `MyApp.Features.{FeatureName}.{Subfolder}`

## CQRS with MediatR

Commands mutate state, queries read it. Both return `ErrorOr<T>`.

### Command Pattern

```csharp
// Command record + handler in the same file
public record CreateItemCommand(
    string Name,
    bool Active) : IRequest<ErrorOr<ItemDto>>;

public class CreateItemCommandHandler : IRequestHandler<CreateItemCommand, ErrorOr<ItemDto>>
{
    private readonly IClock _clock;
    private readonly IItemRepository _itemRepository;
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<CreateItemCommandHandler> _logger;

    public CreateItemCommandHandler(
        IClock clock, IItemRepository itemRepository,
        IUnitOfWork unitOfWork, ILogger<CreateItemCommandHandler> logger)
    {
        _clock = clock;
        _itemRepository = itemRepository;
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<ErrorOr<ItemDto>> Handle(
        CreateItemCommand request, CancellationToken cancellationToken)
    {
        var itemResult = Item.Create(request.Name, request.Active, "System", _clock.UtcNow);
        if (itemResult.IsError)
            return itemResult.Errors;

        await _itemRepository.AddAsync(itemResult.Value, cancellationToken);
        await _unitOfWork.SaveChangesAsync(cancellationToken);

        _logger.LogInformation("Created item {ItemId} '{ItemName}'", 
            itemResult.Value.Id, itemResult.Value.Name);

        return itemResult.Value.MapToDto();
    }
}
```

### Query Pattern

```csharp
public record GetItemsQuery(
    bool? ActiveOnly = null) : IRequest<ErrorOr<IEnumerable<ItemDto>>>;

public class GetItemsQueryHandler : IRequestHandler<GetItemsQuery, ErrorOr<IEnumerable<ItemDto>>>
{
    private readonly IItemRepository _itemRepository;

    public GetItemsQueryHandler(IItemRepository itemRepository)
    {
        _itemRepository = itemRepository;
    }

    public async Task<ErrorOr<IEnumerable<ItemDto>>> Handle(
        GetItemsQuery request, CancellationToken cancellationToken)
    {
        var items = await _itemRepository.GetAllAsync(cancellationToken);

        if (request.ActiveOnly.HasValue)
            items = items.Where(i => i.Active == request.ActiveOnly.Value);

        return items.Select(i => i.MapToDto()).ToList();
    }
}
```

### Key Rules

- **PascalCase for record parameters**: `CreateItemCommand(string Name)` not `(string name)`
- **Commands return `ErrorOr<TDto>` or `ErrorOr<Success>`**
- **No generic try/catch in handlers** — let ErrorOr handle expected failures, exceptions bubble to global handler
- **Inject `IClock` for timestamps** — never use `DateTimeOffset.UtcNow` directly
- **Favour `ErrorOr<Success>` over `ErrorOr<Unit>`** for void operations

## Domain Modeling

### Aggregate Root Pattern

Co-locate all related types in one file:

```csharp
// 1. Aggregate ID (value object)
public class ItemId : ValueObject
{
    public Guid Value { get; }
    private ItemId() { }
    private ItemId(Guid value) { Value = value; }

    public static ItemId CreateUnique() => new(Guid.NewGuid());
    public static ItemId Create(Guid value) => new(value);

    public static ErrorOr<ItemId> Create(string value)
    {
        return Guid.TryParse(value, out var result)
            ? new ItemId(result)
            : ItemErrors.InvalidId();
    }

    protected override IEnumerable<object> GetEqualityComponents()
    {
        yield return Value;
    }

    public override string ToString() => Value.ToString();
}

// 2. Aggregate root
public class Item : AggregateRoot<ItemId>
{
    public string Name { get; private set; } = string.Empty;
    public bool Active { get; private set; }
    public string CreatedBy { get; private set; } = string.Empty;
    public DateTimeOffset CreatedTs { get; private set; }
    public DateTimeOffset UpdatedTs { get; private set; }

    private Item() : base(default!) { } // EF Core constructor

    private Item(ItemId id, string name, bool active, string createdBy, DateTimeOffset ts)
        : base(id)
    {
        Name = name;
        Active = active;
        CreatedBy = createdBy;
        CreatedTs = ts;
        UpdatedTs = ts;
        AddDomainEvent(new ItemCreated(id, name, ts));
    }

    public static ErrorOr<Item> Create(string name, bool active, string createdBy, DateTimeOffset ts)
    {
        if (string.IsNullOrWhiteSpace(name))
            return ItemErrors.EmptyName();
        if (name.Length > 100)
            return ItemErrors.NameTooLong();
        if (string.IsNullOrWhiteSpace(createdBy))
            return ItemErrors.EmptyCreatedBy();

        return new Item(ItemId.CreateUnique(), name, active, createdBy, ts);
    }

    public ErrorOr<Success> Update(string name, bool active, DateTimeOffset ts)
    {
        if (string.IsNullOrWhiteSpace(name))
            return ItemErrors.EmptyName();
        if (name.Length > 100)
            return ItemErrors.NameTooLong();

        Name = name;
        Active = active;
        UpdatedTs = ts;
        AddDomainEvent(new ItemUpdated(Id, Name, ts));
        return Result.Success;
    }
}

// 3. Domain events
public record ItemCreated(ItemId Id, string Name, DateTimeOffset Ts) : IDomainEvent;
public record ItemUpdated(ItemId Id, string Name, DateTimeOffset Ts) : IDomainEvent;

// 4. Domain errors
public static class ItemErrors
{
    public static Error EmptyName() => Error.Validation(
        "Item.Name.Empty", "Item name cannot be empty.");
    public static Error NameTooLong() => Error.Validation(
        "Item.Name.TooLong", "Item name cannot exceed 100 characters.");
    public static Error EmptyCreatedBy() => Error.Validation(
        "Item.CreatedBy.Empty", "Created by cannot be empty.");
    public static Error InvalidId() => Error.Validation(
        "Item.Id.Invalid", "Invalid item ID format.");
    public static Error NotFound() => Error.NotFound(
        "Item.NotFound", "Item not found.");
}

// 5. DTO
public record ItemDto(
    string Id, string Name, bool Active,
    string CreatedBy, DateTimeOffset CreatedTs, DateTimeOffset UpdatedTs);

// 6. Mapping extensions
public static class ItemExtensions
{
    public static ItemDto MapToDto(this Item item) => new(
        item.Id.ToString(), item.Name, item.Active,
        item.CreatedBy, item.CreatedTs, item.UpdatedTs);
}

// 7. Repository interface
public interface IItemRepository
{
    Task<IEnumerable<Item>> GetAllAsync(CancellationToken ct);
    Task<Item?> GetByIdAsync(ItemId id, CancellationToken ct);
    Task<Item?> GetByNameAsync(string name, CancellationToken ct);
    Task AddAsync(Item item, CancellationToken ct);
    Task DeleteAsync(ItemId id, CancellationToken ct);
}

// 8. Repository implementation
public class PostgresItemRepository : IItemRepository
{
    private readonly AppDbContext _dbContext;

    public PostgresItemRepository(AppDbContext dbContext) { _dbContext = dbContext; }

    public async Task<IEnumerable<Item>> GetAllAsync(CancellationToken ct)
        => await _dbContext.Items.ToListAsync(ct);

    public async Task<Item?> GetByIdAsync(ItemId id, CancellationToken ct)
        => await _dbContext.Items.FirstOrDefaultAsync(i => i.Id.Equals(id), ct);

    public async Task<Item?> GetByNameAsync(string name, CancellationToken ct)
        => await _dbContext.Items.FirstOrDefaultAsync(i => i.Name == name, ct);

    public async Task AddAsync(Item item, CancellationToken ct)
        => await _dbContext.Items.AddAsync(item, ct);

    public async Task DeleteAsync(ItemId id, CancellationToken ct)
    {
        var item = await GetByIdAsync(id, ct);
        if (item is not null) _dbContext.Items.Remove(item);
    }
}

// 9. EF Core configuration
public class ItemConfiguration : IEntityTypeConfiguration<Item>
{
    public void Configure(EntityTypeBuilder<Item> builder)
    {
        builder.ToTable("items");
        builder.HasKey(i => i.Id);
        builder.Property(i => i.Id)
            .HasConversion(id => id.Value, value => ItemId.Create(value));
        builder.Property(i => i.Name).HasMaxLength(100).IsRequired();
        builder.Property(i => i.Active).IsRequired();
        builder.Property(i => i.CreatedBy).HasMaxLength(100).IsRequired();
        builder.Property(i => i.CreatedTs).IsRequired();
        builder.Property(i => i.UpdatedTs).IsRequired();
        builder.Ignore(i => i.DomainEvents);
    }
}
```

## ErrorOr Pattern

**Expected failures** return `ErrorOr` errors. **Unexpected failures** bubble to `GlobalExceptionHandlerMiddleware`.

```csharp
// In domain: factory methods return ErrorOr<T>
public static ErrorOr<Item> Create(string name, ...) { ... }

// In handlers: chain ErrorOr results
var result = Item.Create(request.Name, ...);
if (result.IsError) return result.Errors;

// In PageModels: use Match/MatchAsync
result.Match(
    success => ...,
    errors => ...);

// Convert errors to UI display
ErrorDetails = result.Errors.ToErrorDetails();
```

## DependencyInjection Per Feature

```csharp
namespace MyApp.Features.Items;

public static class DependencyInjection
{
    public static IServiceCollection AddItemServices(this IServiceCollection services)
    {
        services.AddScoped<IItemRepository, PostgresItemRepository>();
        return services;
    }
}
```

Register in `Program.cs`:
```csharp
builder.Services.AddItemServices();
```

## Error Handling Philosophy

| Type | Approach | Where |
|------|----------|-------|
| Validation failure | `ErrorOr` from domain | Domain factory/update methods |
| Not found | `ErrorOr` from handler | Query/command handlers |
| Business rule violation | `ErrorOr` from domain | Domain methods |
| DB connection failure | Exception → global handler | Infrastructure |
| Unexpected error | Exception → global handler | Anywhere |

The `GlobalExceptionHandlerMiddleware` catches all unhandled exceptions and:
- Logs with structured context (CorrelationId, Path, Method)
- Returns JSON for API/AJAX requests
- Returns SSE error for SSE requests
- Redirects to `/Error` for page requests

## The Tao of Datastar

Datastar is just a tool. The Tao of Datastar, or “the Datastar way” as it is often referred to, is a set of opinions from the core team on how to best use Datastar to build maintainable, scalable, high-performance web apps.

Ignore them at your own peril!

### State in the Right Place

Most state should live in the backend. Since the frontend is exposed to the user, the backend should be the source of truth for your application state.

### Start with the Defaults

The default configuration options are the recommended settings for the majority of applications. Start with the defaults, and before you ever get tempted to change them, stop and ask yourself, well... how did I get here?

### Patch Elements & Signals

Since the backend is the source of truth, it should drive the frontend by patching (adding, updating and removing) HTML elements and signals.

### Use Signals Sparingly

Overusing signals typically indicates trying to manage state on the frontend. Favor fetching current state from the backend rather than pre-loading and assuming frontend state is current. A good rule of thumb is to only use signals for user interactions (e.g. toggling element visibility) and for sending new state to the backend (e.g. by binding signals to form input elements).

### In Morph We Trust

Morphing ensures that only modified parts of the DOM are updated, preserving state and improving performance. This allows you to send down large chunks of the DOM tree (all the way up to the html tag), sometimes known as “fat morph”, rather than trying to manage fine-grained updates yourself. If you want to explicitly ignore morphing an element, place the data-ignore-morph attribute on it.

### SSE Responses

SSE responses allow you to send 0 to n events, in which you can patch elements, patch signals, and execute scripts. Since event streams are just HTTP responses with some special formatting that SDKs can handle for you, there’s no real benefit to using a content type other than text/event-stream.

### Compression

Since SSE responses stream events from the backend and morphing allows sending large chunks of DOM, compressing the response is a natural choice. Compression ratios of 200:1 are not uncommon when compressing streams using Brotli. Read more about compressing streams in this article.

### Backend Templating

Since your backend generates your HTML, you can and should use your templating language to keep things DRY (Don’t Repeat Yourself).

### Page Navigation

Page navigation hasn't changed in 30 years. Use the anchor element (<a>) to navigate to a new page, or a redirect if redirecting from the backend. For smooth page transitions, use the View Transition API.

### Browser History

Browsers automatically keep a history of pages visited. As soon as you start trying to manage browser history yourself, you are adding complexity. Each page is a resource. Use anchor tags and let the browser do what it is good at.

### CQRS

CQRS, in which commands (writes) and requests (reads) are segregated, makes it possible to have a single long-lived request to receive updates from the backend (reads), while making multiple short-lived requests to the backend (writes). It is a powerful pattern that makes real-time collaboration simple using Datastar. Here’s a basic example.

```html
<div id="main" data-init="@get('/cqrs_endpoint')">
    <button data-on:click="@post('/do_something')">
        Do something
    </button>
</div>
```

### Loading Indicators

Loading indicators inform the user that an action is in progress. Use the data-indicator attribute to show loading indicators on elements that trigger backend requests. Here’s an example of a button that shows a loading element while waiting for a response from the backend.

```html
<div>
    <button data-indicator:_loading
            data-on:click="@post('/do_something')"
    >
        Do something
        <span data-show="$_loading">Loading...</span>
    </button>
</div>
```

When using CQRS, it is generally better to manually show a loading indicator when backend requests are made, and allow it to be hidden when the DOM is updated from the backend. Here’s an example.

```html
<div>
    <button data-on:click="el.classList.add('loading'); @post('/do_something')">
        Do something
        <span>Loading...</span>
    </button>
</div>
```

### Optimistic Updates

Optimistic updates (also known as optimistic UI) are when the UI updates immediately as if an operation succeeded, before the backend actually confirms it. It is a strategy used to makes web apps feel snappier, when it in fact deceives the user. Imagine seeing a confirmation message that an action succeeded, only to be shown a second later that it actually failed. Rather than deceive the user, use loading indicators to show the user that the action is in progress, and only confirm success from the backend (see this example).

### Accessibility

The web should be accessible to everyone. Datastar stays out of your way and leaves accessibility to you. Use semantic HTML, apply ARIA where it makes sense, and ensure your app works well with keyboards and screen readers. Here’s an example of using data-attr to apply ARIA attributes to a button that toggles the visibility of a menu.

```html
<button data-on:click="$_menuOpen = !$_menuOpen"
        data-attr:aria-expanded="$_menuOpen ? 'true' : 'false'"
>
    Open/Close Menu
</button>
<div data-attr:aria-hidden="$_menuOpen ? 'false' : 'true'"></div>
```

## Gotchas

### DateTimeOffset vs DateTime vs DateOnly

PostgreSQL's `timestamp with time zone` requires UTC values. The system uses `DateTimeOffset` for all genuine date-time values (e.g., `CreatedTs`, `UpdatedTs`).

**Never use bare `DateTime`** for entity properties stored in PostgreSQL — you will get:

> `ArgumentException: Cannot write DateTime with Kind=Unspecified to PostgreSQL type 'timestamp with time zone', only UTC is supported. Note that it's not possible to mix DateTimes with different Kinds in an array, range, or multirange. (Parameter 'value')`

**Rules:**
- Timestamps / audit fields → `DateTimeOffset` (always UTC via `IClock.UtcNow`)
- Date-only fields (e.g., birth date, due date) → `DateOnly`
- Never use bare `DateTime` for database-persisted properties
- When creating `DateTimeOffset` values, always use `DateTimeOffset.UtcNow` or the injected `IClock.UtcNow`, never `DateTime.Now`

### Razor Pages Routing

Details pages live at `Pages/Items/Details.cshtml` with `@page "{id}"`, making the route `/Items/Details/{id}` — **not** `/Items/{id}`. Always use tag helpers (`asp-page="Details" asp-route-id="@item.Id"`) or the full explicit path.
