# Datastar SSE on Javalin

The official SDK is `dev.data-star:datastar-java-sdk-core`. It has a servlet adapter and a JAX-RS adapter. It does not have Javalin. Write two small adapters against the SDK interfaces. Do not hand-roll the SSE event names. Datastar's wire format is the SDK's job.

## Adapters

```java
package pkg.web;

import io.javalin.http.Context;
import java.io.BufferedReader;
import java.io.ByteArrayInputStream;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.io.PrintWriter;
import java.nio.charset.StandardCharsets;
import starfederation.datastar.adapters.request.RequestAdapter;
import starfederation.datastar.adapters.response.ResponseAdapter;

public final class JavalinResponseAdapter implements ResponseAdapter {
    private final Context ctx;
    public JavalinResponseAdapter(Context ctx) { this.ctx = ctx; }

    @Override public PrintWriter getWriter() {
        return new PrintWriter(new OutputStreamWriter(ctx.outputStream(), StandardCharsets.UTF_8), true);
    }
    @Override public void setHeader(String name, String value) { ctx.header(name, value); }
    @Override public void setContentType(String contentType) { ctx.contentType(contentType); }
    @Override public void setCharacterEncoding(String encoding) { /* charset is UTF-8 on the writer */ }
    @Override public void setStatus(int status) { ctx.status(status); }
}

public final class JavalinRequestAdapter implements RequestAdapter {
    private final Context ctx;
    public JavalinRequestAdapter(Context ctx) { this.ctx = ctx; }

    @Override public String getMethod() { return ctx.method().name(); }
    @Override public String getParameter(String name) { return ctx.queryParam(name); }
    @Override public BufferedReader getReader() {
        return new BufferedReader(new InputStreamReader(
                new ByteArrayInputStream(ctx.bodyAsBytes()), StandardCharsets.UTF_8));
    }
}
```

If a future SDK release adds `javalin`, delete these and use it. Until then this is the Java-native glue.

## Sending patches

```java
import starfederation.datastar.events.PatchElements;
import starfederation.datastar.events.PatchSignals;
import starfederation.datastar.utils.ServerSentEventGenerator;

public final class Sse {
    public static boolean isDatastar(Context ctx) {
        String accept = ctx.header("Accept");
        return accept != null && accept.contains("text/event-stream");
    }

    public static ServerSentEventGenerator generator(Context ctx) {
        return new ServerSentEventGenerator(new JavalinResponseAdapter(ctx));
    }

    public static void patch(Context ctx, String html) throws Exception {
        var gen = generator(ctx);
        gen.send(PatchElements.builder().data(html).build());
    }

    public static void patch(Context ctx, String selector, String html) throws Exception {
        var gen = generator(ctx);
        gen.send(PatchElements.builder().selector(selector).data(html).build());
    }

    public static void signals(Context ctx, String json) throws Exception {
        var gen = generator(ctx);
        gen.send(PatchSignals.builder().data(json).build());
    }
}
```

Default patch mode is outer morph on the element's `id`. Give fragments a stable id (`id="items-table"`). Fat morph is the tao. Do not micro-manage siblings unless you have a reason.

Long-lived live views: keep the generator and loop. Virtual threads make this cheap. Close when the client drops (`IOException` from `send`). Do not swallow that and keep looping.

## Rendering a fragment to a string

Javalin `ctx.render` writes to the response. For SSE you need a string:

```java
import gg.jte.TemplateEngine;
import gg.jte.output.StringOutput;

StringOutput out = new StringOutput();
templateEngine.render("items/table.jte", page, out);
Sse.patch(ctx, out.toString());
```

Hold the same `TemplateEngine` JavalinJte is using, or construct one in `UiServer` and pass it to routes. Do not create an engine per request.

## Reading signals

```java
DataStore store = new DataStore();
SignalReader.readSignals(new JavalinRequestAdapter(ctx), store);
```

Check the SDK's `DataStore` / `SignalReader` names if the compiler disagrees. The 1.0.0 README shows `SignalReader.readSignals(request, store)`. Prefer form POST + redirect for create/edit. Use signals for search boxes, pagination, and delete confirmations.

Search that patches the table:

```html
<input data-bind:items.searchQuery
       data-on:input__debounce.300ms="@get('/items/table')">
```

The GET handler reads the query param or the signal, renders `table.jte`, patches `#items-table`.

## CQRS shape (Datastar's, not MediatR)

One long-lived GET for reads (`data-init="@get('/campaigns/42/live')"`). Short POSTs for writes. After a write, either redirect (full page) or patch the fragment the GET would have returned.

```html
<div id="main" data-init="@get('/items/table')">
    <button data-on:click="@post('/items/123/delete')">Delete</button>
</div>
```

## Loading

```html
<button data-indicator:_loading data-on:click="@post('/items')">
    Save
    <span data-show="$_loading">Saving...</span>
</button>
```

No optimistic UI. The tao is explicit about that. Wait for the patch.

## Pin the JS

Serve `/js/datastar.js` from this skill's `assets/js/datastar.js`. Do not CDN it. Do not `npm install @starfederation/datastar` in a Java app. The file in git is the version.
