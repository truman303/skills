# Toasts & Notifications — Models, Partials, Configuration

Toast and inline message system for SSE-patched notifications and full-page alerts.

## ToastModel.cs

```csharp
using MyApp.Shared.Errors;

namespace MyApp.Shared.Toasts;

public class ToastModel
{
    public string Title { get; }
    public string Message { get; }
    public List<ErrorDetail> Errors { get; } = [];
    public string Code { get; }

    public ToastModel(string title, string message, List<ErrorDetail>? errors = null, string? code = null)
    {
        Title = title;
        Message = message;
        Errors = errors ?? [];
        Code = code ?? string.Empty;
    }
}
```

## ToastViewModel.cs

```csharp
using MyApp.Shared.Errors;

namespace MyApp.Shared.Toasts;

public class ToastViewModel
{
    public string Category { get; set; } = "info";
    public string Title { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public List<ErrorDetail>? Errors { get; set; }
}
```

## ToasterConfiguration.cs

```csharp
using StarFederation.Datastar.DependencyInjection;

namespace MyApp.Shared.Toasts;

public static class ToasterConfiguration
{
    public const string TOAST_SELECTOR = "#toaster";

    public static readonly PatchElementsOptions ToastPatchOptions = new()
    {
        Selector = TOAST_SELECTOR,
        PatchMode = StarFederation.Datastar.ElementPatchMode.Append
    };
}
```

## MessageViewModel.cs

```csharp
using MyApp.Shared.Errors;

namespace MyApp.Shared.Messages;

public record MessageViewModel(
    string Category,
    string Title,
    string Message,
    string? InfoMessage = null,
    List<ErrorDetail>? Errors = null,
    string? ContainerId = null);
```

## _Message.cshtml (Inline Message Partial)

```html
@model MyApp.Shared.Messages.MessageViewModel

<div class="@(Model.ContainerId is not null ? "" : "mb-4") rounded-lg border p-4 @(Model.Category switch {
    "success" => "border-green-200 bg-green-50 dark:border-green-900 dark:bg-green-950/30",
    "error" => "border-red-200 bg-red-50 dark:border-red-900 dark:bg-red-950/30",
    "warning" => "border-amber-200 bg-amber-50 dark:border-amber-900 dark:bg-amber-950/30",
    _ => "border-blue-200 bg-blue-50 dark:border-blue-900 dark:bg-blue-950/30"
})">
    <div class="flex items-start gap-3">
        <div class="flex-1">
            <h4 class="text-sm font-semibold @(Model.Category switch {
                "success" => "text-green-800 dark:text-green-200",
                "error" => "text-red-800 dark:text-red-200",
                "warning" => "text-amber-800 dark:text-amber-200",
                _ => "text-blue-800 dark:text-blue-200"
            })">@Model.Title</h4>
            <p class="text-sm mt-1 @(Model.Category switch {
                "success" => "text-green-700 dark:text-green-300",
                "error" => "text-red-700 dark:text-red-300",
                "warning" => "text-amber-700 dark:text-amber-300",
                _ => "text-blue-700 dark:text-blue-300"
            })">@Model.Message</p>
            @if (Model.InfoMessage is not null)
            {
                <p class="text-sm mt-1 text-muted-foreground">@Model.InfoMessage</p>
            }
            @if (Model.Errors is not null && Model.Errors.Any())
            {
                <ul class="mt-2 list-disc pl-4 text-sm space-y-1">
                    @foreach (var error in Model.Errors)
                    {
                        <li>@error.Description</li>
                    }
                </ul>
            }
        </div>
        @if (Model.ContainerId is not null)
        {
            <button type="button" class="text-muted-foreground hover:text-foreground"
                    onclick="this.closest('[class*=rounded-lg]').remove()">
                <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>
            </button>
        }
    </div>
</div>
```

## _Toast.cshtml (Toast Notification Partial)

```html
@model MyApp.Shared.Toasts.ToastViewModel

<div class="toast @(Model.Category switch {
    "success" => "toast-success",
    "error" => "toast-error",
    "warning" => "toast-warning",
    _ => "toast-info"
})" data-auto-dismiss="5000">
    <div class="flex items-start gap-3">
        <div class="flex-1">
            <h4 class="text-sm font-semibold">@Model.Title</h4>
            @if (!string.IsNullOrWhiteSpace(Model.Message))
            {
                <p class="text-sm mt-1">@Model.Message</p>
            }
        </div>
        <button type="button" class="text-muted-foreground hover:text-foreground"
                onclick="this.closest('.toast').remove()">
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>
        </button>
    </div>
</div>
```

## Usage Decision Tree

| Context | Success | Error |
|---------|---------|-------|
| Redirect after Create/Edit | `TempData["SuccessMessage"]` | `ErrorDetails` on same page |
| SSE table fragment | `CreateAndPatchSuccessToastAsync` | `CreateAndPatchErrorMessageAsync` |
| SSE POST from table | Toast | Inline message |
| Full page GET | N/A | `ErrorDetails` |
