# Domain — Base Classes, DbContext, Clock

DDD building blocks, database context, and cross-cutting infrastructure for feature registration.

## Entity.cs

```csharp
namespace MyApp.Shared.Models;

public abstract class Entity<TId> : IEquatable<Entity<TId>>, IHasDomainEvents
    where TId : notnull
{
    private readonly List<IDomainEvent> _domainEvents = [];

    public TId Id { get; protected set; }
    public IReadOnlyList<IDomainEvent> DomainEvents => _domainEvents.AsReadOnly();

    protected Entity(TId id) { Id = id; }

    public override bool Equals(object? obj)
        => obj is Entity<TId> entity && entity.Id.Equals(Id);

    public bool Equals(Entity<TId>? other)
        => Equals((object?)other);

    public static bool operator ==(Entity<TId> a, Entity<TId> b) => Equals(a, b);
    public static bool operator !=(Entity<TId> a, Entity<TId> b) => !Equals(a, b);

    public override int GetHashCode() => Id.GetHashCode();

    public void AddDomainEvent(IDomainEvent domainEvent) => _domainEvents.Add(domainEvent);
    public void ClearDomainEvents() => _domainEvents.Clear();
}
```

## AggregateRoot.cs

```csharp
namespace MyApp.Shared.Models;

public abstract class AggregateRoot<TId> : Entity<TId>
    where TId : notnull
{
    protected AggregateRoot(TId id) : base(id) { }
}
```

## ValueObject.cs

```csharp
namespace MyApp.Shared.Models;

public abstract class ValueObject : IEquatable<ValueObject>
{
    protected abstract IEnumerable<object> GetEqualityComponents();

    public override bool Equals(object? obj)
    {
        if (obj is null || obj.GetType() != GetType()) return false;
        var valueObject = (ValueObject)obj;
        return GetEqualityComponents().SequenceEqual(valueObject.GetEqualityComponents());
    }

    public static bool operator ==(ValueObject a, ValueObject b) => Equals(a, b);
    public static bool operator !=(ValueObject a, ValueObject b) => !Equals(a, b);

    public override int GetHashCode()
        => GetEqualityComponents().Select(x => x?.GetHashCode() ?? 0).Aggregate((x, y) => x ^ y);

    public bool Equals(ValueObject? other) => Equals((object?)other);
}
```

## IDomainEvent.cs

```csharp
using MediatR;

namespace MyApp.Shared.Models;

public interface IDomainEvent : INotification { }
```

## IHasDomainEvents.cs

```csharp
namespace MyApp.Shared.Models;

public interface IHasDomainEvents
{
    IReadOnlyList<IDomainEvent> DomainEvents { get; }
    void ClearDomainEvents();
}
```

## AppDbContext.cs

Inherits `IdentityDbContext<IdentityUser>` to provide Identity tables (users, roles, claims, etc.) alongside app entities:

```csharp
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using MyApp.Shared.Models;

namespace MyApp.Features.Shared.Database;

public class AppDbContext : IdentityDbContext<IdentityUser>
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    // Register DbSets per feature (one line per aggregate root)
    // public DbSet<Item> Items => Set<Item>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        builder.Ignore<List<IDomainEvent>>();

        // Apply entity configurations (one per feature aggregate)
        // builder.ApplyConfiguration(new ItemConfiguration());
    }
}
```

## IClock.cs

```csharp
namespace MyApp.Shared.Clocks;

public interface IClock
{
    DateTimeOffset UtcNow { get; }
}

public class Clock : IClock
{
    public DateTimeOffset UtcNow => DateTimeOffset.UtcNow;
}
```

## Feature DependencyInjection Pattern

Each feature registers its own services:

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

Called from `Program.cs`:
```csharp
builder.Services.AddItemServices();
```
