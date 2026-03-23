# Control Flow — ErrorOr, RazorPageExtensions, Middleware, Unit of Work

Error handling pipeline, SSE patching helpers, global exception middleware, and persistence boundary.

## ErrorDetail.cs

```csharp
using ErrorOr;

namespace MyApp.Shared.Errors;

public class ErrorDetail
{
    public string Code { get; init; } = string.Empty;
    public string Description { get; init; } = string.Empty;

    private ErrorDetail(string code, string description)
    {
        Code = code;
        Description = description;
    }

    public static ErrorDetail Create(Error error) => new(error.Code, error.Description);
}
```

## ErrorOrExtensions.cs

```csharp
using ErrorOr;

namespace MyApp.Shared.Errors;

public static class ErrorOrExtensions
{
    public static List<ErrorDetail> ToErrorDetails(this IEnumerable<Error> errors)
        => [.. errors.Select(e => ErrorDetail.Create(e))];

    public static ErrorDetail ToErrorDetail(this Error error)
        => ErrorDetail.Create(error);
}
```

## RazorPageExtensions.cs

SSE helpers for patching partials, messages, and toasts:

```csharp
using ErrorOr;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MyApp.Shared.Errors;
using MyApp.Shared.Messages;
using MyApp.Shared.Toasts;
using StarFederation.Datastar;
using StarFederation.Datastar.DependencyInjection;

namespace MyApp.Features.Shared.Extensions;

public static class RazorPageExtensions
{
    /// <summary>
    /// Render a partial view and patch it into the page via SSE
    /// </summary>
    public static async Task<EmptyResult> CreateAndPatchPartialAsync(
        this PageModel pageModel,
        object model,
        string partialName,
        IDatastarService datastarService,
        ILogger logger,
        CancellationToken cancellationToken)
    {
        try
        {
            var html = await pageModel.RenderPartialToStringAsync(partialName, model);
            await datastarService.PatchElementsAsync(html, cancellationToken: cancellationToken);
        }
        catch (Exception ex) when (ex is OperationCanceledException or TaskCanceledException)
        {
            logger.LogInformation("Partial patch cancelled");
        }
        return new EmptyResult();
    }

    /// <summary>
    /// Patch a dismissible error message into the SSE message container
    /// </summary>
    public static async Task<EmptyResult> CreateAndPatchErrorMessageAsync(
        this PageModel pageModel,
        List<Error> errors,
        IDatastarService datastarService,
        ILogger logger,
        CancellationToken cancellationToken)
    {
        try
        {
            var messageVm = new MessageViewModel(
                Category: "error",
                Title: "Error",
                Message: errors.Count > 1
                    ? $"{errors.Count} errors occurred:"
                    : errors.First().Description,
                Errors: errors.Count > 1 ? errors.ToErrorDetails() : null,
                ContainerId: "sse-message-container");

            var html = await pageModel.RenderPartialToStringAsync("_Message", messageVm);
            await datastarService.PatchElementsAsync(html,
                new PatchElementsOptions
                {
                    Selector = "#sse-message-container",
                    PatchMode = ElementPatchMode.Inner
                },
                cancellationToken);
        }
        catch (Exception ex) when (ex is OperationCanceledException or TaskCanceledException)
        {
            logger.LogInformation("Error message patch cancelled");
        }
        return new EmptyResult();
    }

    /// <summary>
    /// Single error overload
    /// </summary>
    public static Task<EmptyResult> CreateAndPatchErrorMessageAsync(
        this PageModel pageModel,
        Error error,
        IDatastarService datastarService,
        ILogger logger,
        CancellationToken cancellationToken)
        => pageModel.CreateAndPatchErrorMessageAsync([error], datastarService, logger, cancellationToken);

    /// <summary>
    /// Append a success toast notification via SSE
    /// </summary>
    public static async Task<EmptyResult> CreateAndPatchSuccessToastAsync(
        this PageModel pageModel,
        ToastModel toast,
        IDatastarService datastarService,
        CancellationToken cancellationToken)
    {
        var toastVm = new ToastViewModel
        {
            Category = "success",
            Title = toast.Title,
            Message = toast.Message
        };

        var html = await pageModel.RenderPartialToStringAsync("_Toast", toastVm);
        await datastarService.PatchElementsAsync(html,
            ToasterConfiguration.ToastPatchOptions,
            cancellationToken);

        return new EmptyResult();
    }

    /// <summary>
    /// Render a partial view to string for SSE fragments
    /// </summary>
    private static async Task<string> RenderPartialToStringAsync<TModel>(
        this PageModel pageModel,
        string partialName,
        TModel model)
    {
        var actionContext = new Microsoft.AspNetCore.Mvc.ActionContext(
            pageModel.HttpContext,
            pageModel.RouteData,
            pageModel.PageContext.ActionDescriptor);

        var serviceProvider = pageModel.HttpContext.RequestServices;
        var viewEngine = serviceProvider.GetRequiredService<Microsoft.AspNetCore.Mvc.Razor.IRazorViewEngine>();
        var tempDataProvider = serviceProvider.GetRequiredService<Microsoft.AspNetCore.Mvc.ViewFeatures.ITempDataProvider>();

        var viewData = new Microsoft.AspNetCore.Mvc.ViewFeatures.ViewDataDictionary<TModel>(
            new Microsoft.AspNetCore.Mvc.ModelBinding.EmptyModelMetadataProvider(),
            new Microsoft.AspNetCore.Mvc.ModelBinding.ModelStateDictionary())
        {
            Model = model
        };

        using var sw = new StringWriter();
        var viewResult = viewEngine.GetView(null, partialName, false);
        if (!viewResult.Success)
            viewResult = viewEngine.FindView(actionContext, partialName, false);
        if (!viewResult.Success)
            throw new InvalidOperationException($"Partial view '{partialName}' not found");

        var viewContext = new Microsoft.AspNetCore.Mvc.Rendering.ViewContext(
            actionContext,
            viewResult.View,
            viewData,
            new Microsoft.AspNetCore.Mvc.ViewFeatures.TempDataDictionary(
                actionContext.HttpContext, tempDataProvider),
            sw,
            new Microsoft.AspNetCore.Mvc.ViewFeatures.HtmlHelperOptions());

        await viewResult.View.RenderAsync(viewContext);
        return sw.ToString();
    }
}
```

## GlobalExceptionHandlerMiddleware.cs

```csharp
using System.Diagnostics;
using System.Net;
using System.Text.Json;

namespace MyApp.Features.Shared.Exceptions;

public class GlobalExceptionHandlerMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<GlobalExceptionHandlerMiddleware> _logger;
    private readonly IHostEnvironment _environment;

    public GlobalExceptionHandlerMiddleware(
        RequestDelegate next,
        ILogger<GlobalExceptionHandlerMiddleware> logger,
        IHostEnvironment environment)
    {
        _next = next;
        _logger = logger;
        _environment = environment;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (OperationCanceledException) when (context.RequestAborted.IsCancellationRequested)
        {
            _logger.LogDebug("Request cancelled by client: {Path}", context.Request.Path);
            if (!context.Response.HasStarted)
                context.Response.StatusCode = 499;
        }
        catch (Exception ex)
        {
            await HandleExceptionAsync(context, ex);
        }
    }

    private async Task HandleExceptionAsync(HttpContext context, Exception exception)
    {
        var correlationId = Activity.Current?.Id ?? context.TraceIdentifier;

        _logger.LogError(exception,
            "Unhandled exception. CorrelationId: {CorrelationId}, Path: {Path}, Method: {Method}",
            correlationId, context.Request.Path, context.Request.Method);

        if (context.Response.HasStarted) return;

        if (IsApiOrAjaxRequest(context))
        {
            context.Response.StatusCode = (int)HttpStatusCode.InternalServerError;
            context.Response.ContentType = "application/json";
            var json = JsonSerializer.Serialize(new
            {
                correlationId,
                message = _environment.IsDevelopment() ? exception.Message : "An unexpected error occurred."
            });
            await context.Response.WriteAsync(json);
        }
        else if (IsSseRequest(context))
        {
            context.Response.StatusCode = (int)HttpStatusCode.OK;
            context.Response.ContentType = "text/event-stream";
            await context.Response.WriteAsync(
                $"event: error\ndata: {{\"correlationId\":\"{correlationId}\",\"message\":\"An error occurred.\"}}\n\n");
        }
        else
        {
            context.Response.Redirect($"/Error?correlationId={correlationId}");
        }
    }

    private static bool IsApiOrAjaxRequest(HttpContext context)
        => context.Request.Headers.XRequestedWith == "XMLHttpRequest"
           || context.Request.Headers.Accept.ToString().Contains("application/json")
           || context.Request.Path.StartsWithSegments("/api");

    private static bool IsSseRequest(HttpContext context)
        => context.Request.Headers.Accept.ToString().Contains("text/event-stream");
}

public static class GlobalExceptionHandlerMiddlewareExtensions
{
    public static IApplicationBuilder UseGlobalExceptionHandler(this IApplicationBuilder app)
        => app.UseMiddleware<GlobalExceptionHandlerMiddleware>();
}
```

## IUnitOfWork.cs (Simple Pattern)

For single-database apps, the DbContext itself acts as the unit of work:

```csharp
namespace MyApp.Features.Shared.Database;

public interface IUnitOfWork
{
    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}

public class UnitOfWork : IUnitOfWork
{
    private readonly AppDbContext _dbContext;

    public UnitOfWork(AppDbContext dbContext) { _dbContext = dbContext; }

    public Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
        => _dbContext.SaveChangesAsync(cancellationToken);
}
```

Register in DI:
```csharp
builder.Services.AddScoped<IUnitOfWork, UnitOfWork>();
```
