# Shared Infrastructure Reference

Foundation classes for `Features/Shared/`. Each area has its own detailed reference.

## File Layout

```
Features/
└── Shared/
    ├── Database/
    │   ├── AppDbContext.cs
    │   ├── IUnitOfWork.cs
    │   └── UnitOfWork.cs
    ├── Exceptions/
    │   └── GlobalExceptionHandlerMiddleware.cs
    ├── Extensions/
    │   └── RazorPageExtensions.cs
    ├── Models/
    │   ├── Entity.cs
    │   ├── AggregateRoot.cs
    │   ├── ValueObject.cs
    │   ├── IDomainEvent.cs
    │   └── IHasDomainEvents.cs
    └── DependencyInjection.cs

Shared/
├── Clocks/
│   └── IClock.cs
├── Errors/
│   ├── ErrorDetail.cs
│   └── ErrorOrExtensions.cs
├── Messages/
│   └── MessageViewModel.cs
└── Toasts/
    ├── ToastModel.cs
    ├── ToastViewModel.cs
    └── ToasterConfiguration.cs

Pages/Shared/
├── _Message.cshtml
└── _Toast.cshtml
```

## Detailed References

- [shared-domain.md](shared-domain.md) — Base classes (Entity, AggregateRoot, ValueObject, IDomainEvent), AppDbContext, IClock, Feature DI pattern
- [shared-control-flow.md](shared-control-flow.md) — ErrorOr helpers, RazorPageExtensions (SSE patching), GlobalExceptionHandlerMiddleware, IUnitOfWork
- [shared-toasts-notifications.md](shared-toasts-notifications.md) — ToastModel, MessageViewModel, `_Message.cshtml`, `_Toast.cshtml` partials, usage decision tree
