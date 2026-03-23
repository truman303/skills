# Architecture Patterns Reference

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
