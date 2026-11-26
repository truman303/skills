# Datastar and SSE

> Placeholders: `pkg` is the Java package. See SKILL.md.

The browser asks, the server answers with HTML over a `text/event-stream` response, and Datastar morphs that HTML into the page. This file holds the server kit that every feature uses. Copy it into `pkg/web/` as written. All of it has been run against Javalin 7.2, JTE 3.2 and the bundled Datastar.

## Versions

- Browser: `assets/js/datastar.js`, Datastar v1.0.5. The first line of the file names the version.
- Server: `dev.data-star:datastar-java-sdk-core:1.0.1`.

Datastar 1.0 writes attribute keys with a colon: `data-on:click`, `data-indicator:_loading`, `data-attr:disabled`. Release candidates up to RC.5 used a hyphen and ignore the colon form without any error. If no handler fires at all, check which `datastar.js` the page loaded before you debug anything else.

## What crosses the wire

A Datastar action such as `@get('/items/table')` sends:

- the header `Datastar-Request: true`
- every signal whose name does not start with `_`, as JSON. `@get` and `@delete` put it in the query string as `?datastar={...}`. `@post`, `@put` and `@patch` put it in the body.

The server replies with one or more events:

| Event | Effect |
|-------|--------|
| `datastar-patch-elements` | Morphs HTML into the page. With no selector, each top-level element replaces the element with the same `id`. |
| `datastar-patch-elements` with `selector` and `mode` | `append`, `prepend`, `before`, `after`, `inner`, `replace` or `remove` relative to the selector. |
| `datastar-patch-signals` | Merges a JSON object into the page's signals. |

One response can carry several events. A delete answers with the new table, the corrected signals and a toast, in that order.

Two behaviours to know:

- A new request to the same method and URL aborts the one still in flight. Typing fast in a search box therefore never applies a stale table.
- Datastar closes a `@get` stream while the browser tab is hidden and opens it again when the tab returns. A live view must send the current state first on every connect.

## `JavalinResponseAdapter`

The SDK has no Javalin module. It needs one adapter.

```java
package pkg.web;

import io.javalin.http.Context;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.io.PrintWriter;
import java.nio.charset.StandardCharsets;
import starfederation.datastar.adapters.response.AbstractResponseAdapter;

final class JavalinResponseAdapter extends AbstractResponseAdapter {
    private final Context ctx;
    private PrintWriter writer;

    JavalinResponseAdapter(Context ctx) {
        this.ctx = ctx;
    }

    /**
     * The servlet stream, not ctx.outputStream(). Javalin's wrapper ignores flush(), so a
     * long-lived stream would sit in a buffer until the handler returned.
     */
    @Override
    public PrintWriter getWriter() throws IOException {
        if (writer == null) {
            writer = new PrintWriter(new OutputStreamWriter(ctx.res().getOutputStream(), StandardCharsets.UTF_8));
        }
        return writer;
    }

    @Override
    public void setHeader(String name, String value) {
        ctx.header(name, value);
    }

    @Override
    public void setContentType(String contentType) {
        ctx.contentType(contentType);
    }

    @Override
    public void setCharacterEncoding(String encoding) {
        // the writer is already UTF-8
    }

    @Override
    public void setStatus(int status) {
        ctx.status(status);
    }

    /** PrintWriter swallows IOException. This is the only way to learn the browser went away. */
    boolean failed() {
        return writer != null && writer.checkError();
    }
}
```

Extend `AbstractResponseAdapter`. The SDK's generator takes that class, not an interface.

`ctx.res().getOutputStream()` is the part people get wrong. With `ctx.outputStream()` a one-shot response still works, because Javalin flushes when the handler returns. A live view sends nothing and never notices a closed tab.

## `Sse`

One `Sse` per request. Open it, then send as many events as the handler needs.

```java
package pkg.web;

import io.javalin.http.Context;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.function.Supplier;
import starfederation.datastar.enums.ElementPatchMode;
import starfederation.datastar.events.PatchElements;
import starfederation.datastar.events.PatchSignals;
import starfederation.datastar.utils.ServerSentEventGenerator;

public final class Sse {
    private static final Duration HEARTBEAT = Duration.ofSeconds(5);
    private final JavalinResponseAdapter response;
    private final ServerSentEventGenerator events;
    private final Templates templates;

    private Sse(Context ctx, Templates templates) {
        this.response = new JavalinResponseAdapter(ctx);
        this.events = new ServerSentEventGenerator(response);
        this.templates = templates;
    }

    public static Sse open(Context ctx, Templates templates) {
        return new Sse(ctx, templates);
    }

    public static boolean isDatastar(Context ctx) {
        return "true".equals(ctx.header("Datastar-Request"));
    }

    /** Morphs the element whose id matches the template's root element. */
    public Sse patch(String template, Map<String, Object> params) {
        events.send(PatchElements.builder().data(templates.render(template, params)).build());
        return this;
    }

    /** Adds the rendered template as the last child of the selected element. */
    public Sse append(String selector, String template, Map<String, Object> params) {
        events.send(PatchElements.builder()
                .selector(selector)
                .mode(ElementPatchMode.Append)
                .data(templates.render(template, params))
                .build());
        return this;
    }

    public Sse signals(Map<String, Object> signals) {
        events.send(PatchSignals.builder().data(Signals.json(signals)).build());
        return this;
    }

    /**
     * Sends the browser to another page, because a Datastar request cannot follow a 302 to one.
     * The SDK's ExecuteScript event is not used: 1.0.1 emits the script with no selector, and
     * Datastar 1.0.5 drops an element it cannot place. The url must come from the app, never from input.
     */
    public Sse redirect(String url) {
        events.send(PatchElements.builder()
                .selector("body")
                .mode(ElementPatchMode.Append)
                .data("<script data-effect=\"el.remove()\">window.location.href = " + Signals.json(url) + "</script>")
                .build());
        return this;
    }

    public Sse toast(String category, String title, String message) {
        return append("#toaster", "fragments/toast.jte",
                Map.of("category", category, "title", title, "message", message));
    }

    public Sse messages(List<Message> messages) {
        return patch("fragments/messages.jte", Map.of("messages", messages));
    }

    /**
     * A live view. Re-renders on an interval, patches only when the HTML changed, and returns
     * when the browser has gone. The heartbeat matters: a closed tab is only noticed on a write.
     */
    public void live(Duration every, Supplier<String> render) throws InterruptedException {
        String last = null;
        long idleMillis = 0;
        while (isOpen()) {
            String html = render.get();
            if (!html.equals(last)) {
                events.send(PatchElements.builder().data(html).build());
                last = html;
                idleMillis = 0;
            } else if ((idleMillis += every.toMillis()) >= HEARTBEAT.toMillis()) {
                events.send(PatchSignals.builder().data("{}").build());
                idleMillis = 0;
            }
            Thread.sleep(every);
        }
    }

    /** False once a write has failed. */
    public boolean isOpen() {
        return !response.failed();
    }
}
```

Constructing the generator sets `Content-Type: text/event-stream` and flushes the headers. After `Sse.open` the status code is fixed and `ctx.render`, `ctx.result` and `ctx.redirect` no longer make sense. A handler either answers with a page or with an `Sse`, never both.

## `Templates`

Renders a template to a string for a patch. Full pages still go through `ctx.render`.

```java
package pkg.web;

import gg.jte.TemplateEngine;
import gg.jte.output.StringOutput;
import java.util.Map;

public final class Templates {
    private final TemplateEngine engine;

    public Templates(TemplateEngine engine) {
        this.engine = engine;
    }

    public String render(String name, Map<String, Object> params) {
        StringOutput out = new StringOutput();
        engine.render(name, params, out);
        return out.toString();
    }
}
```

## `Signals`

Reads what Datastar sent and writes JSON for `data-signals` and `PatchSignals`. Jackson arrives with the SDK, so there is no extra dependency.

```java
package pkg.web;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.MissingNode;
import io.javalin.http.Context;
import io.javalin.http.HandlerType;

/** The signals Datastar sent with this request. GET and DELETE carry them in ?datastar=, the rest in the body. */
public final class Signals {
    private static final ObjectMapper JSON = new ObjectMapper();
    private final JsonNode root;

    private Signals(JsonNode root) {
        this.root = root;
    }

    public static Signals read(Context ctx) {
        boolean inQuery = ctx.method() == HandlerType.GET || ctx.method() == HandlerType.DELETE;
        String raw = inQuery ? ctx.queryParam("datastar") : ctx.body();
        if (raw == null || !raw.stripLeading().startsWith("{")) {
            return new Signals(MissingNode.getInstance());
        }
        try {
            return new Signals(JSON.readTree(raw));
        } catch (JsonProcessingException e) {
            return new Signals(MissingNode.getInstance());
        }
    }

    /** Pointer is a JSON pointer: "/items/search". */
    public String text(String pointer, String fallback) {
        JsonNode node = root.at(pointer);
        return node.isValueNode() && !node.isNull() ? node.asText() : fallback;
    }

    public int number(String pointer, int fallback) {
        JsonNode node = root.at(pointer);
        return node.isValueNode() && !node.isNull() ? node.asInt(fallback) : fallback;
    }

    /** JSON for a data-signals attribute or a PatchSignals event. */
    public static String json(Object value) {
        try {
            return JSON.writeValueAsString(value);
        } catch (JsonProcessingException e) {
            throw new IllegalArgumentException("not serialisable as signals", e);
        }
    }
}
```

Missing or malformed signals fall back to defaults. A table endpoint hit by hand with no signals renders page one instead of failing.

## `TableState`

Search text, page number and page size for one paged table. On the page it lives in signals. On a full page load it comes from the query string, so `/items?search=bolt&page=3` is a link people can share.

```java
package pkg.web;

import io.javalin.http.Context;
import java.util.List;
import java.util.Map;

public record TableState(String search, int page, int pageSize) {
    public static final List<Integer> PAGE_SIZES = List.of(10, 25, 50);

    public TableState {
        search = search == null ? "" : search.trim();
        page = Math.max(1, page);
        pageSize = PAGE_SIZES.contains(pageSize) ? pageSize : PAGE_SIZES.get(0);
    }

    /** Full page load: /items?search=foo&page=3&pageSize=25 */
    public static TableState fromQuery(Context ctx) {
        return new TableState(
                ctx.queryParam("search"),
                parse(ctx.queryParam("page"), 1),
                parse(ctx.queryParam("pageSize"), PAGE_SIZES.get(0)));
    }

    /** Datastar request. Namespace is the signal object the index page declared: "/items". */
    public static TableState fromSignals(Signals signals, String namespace) {
        return new TableState(
                signals.text(namespace + "/search", ""),
                signals.number(namespace + "/page", 1),
                signals.number(namespace + "/pageSize", PAGE_SIZES.get(0)));
    }

    public int offset() {
        return (page - 1) * pageSize;
    }

    public int totalPages(int totalCount) {
        return Math.max(1, (int) Math.ceil(totalCount / (double) pageSize));
    }

    /** Deleting the last row on the last page leaves the page number past the end. Pull it back. */
    public TableState clampTo(int totalCount) {
        return new TableState(search, Math.min(page, totalPages(totalCount)), pageSize);
    }

    public Map<String, Object> asSignals() {
        return Map.of("search", search, "page", page, "pageSize", pageSize);
    }

    private static int parse(String raw, int fallback) {
        try {
            return raw == null ? fallback : Integer.parseInt(raw.trim());
        } catch (NumberFormatException e) {
            return fallback;
        }
    }
}
```

The compact constructor rejects page sizes that are not on the list, so nobody can ask for a million rows by editing a request.

## `Message`

An inline message at the top of a page. One record serves session flash, validation errors and messages patched over SSE.

```java
package pkg.web;

import java.util.List;
import pkg.ErrorDetail;

/** Category is success, error, warning or info. */
public record Message(String category, String title, List<String> lines) {
    public Message {
        lines = List.copyOf(lines);
    }

    public static Message success(String text) {
        return new Message("success", text, List.of());
    }

    public static Message error(String title, List<ErrorDetail> errors) {
        return new Message("error", title, errors.stream().map(ErrorDetail::message).toList());
    }

    public boolean isError() {
        return category.equals("error");
    }
}
```

The two fragments it renders through, `fragments/messages.jte` and `fragments/toast.jte`, are in [crud-pages.md](crud-pages.md).

## A one-shot response

The handler behind a table's search box, pager and page-size select:

```java
private void table(Context ctx) {
    TableState asked = TableState.fromSignals(Signals.read(ctx), "/items");
    patchTable(Sse.open(ctx, templates), ctx, asked);
}

private void patchTable(Sse sse, Context ctx, TableState asked) {
    IndexPage page = indexPage(ctx, asked, List.of());
    sse.patch("items/table.jte", Map.of("page", page));
    sse.signals(Map.of("items", page.table().asSignals()));
}
```

The signals patch is not optional. The server may have clamped the page number, and the next click computes from whatever the signal says.

The full feature is in [crud-pages.md](crud-pages.md).

## A live view

A panel that keeps itself current while the page is open, such as the progress of a job the user started.

Template `jobs/progress.jte`. The root element carries the id that the morph targets:

```html
@param int done
@param int total

<div id="job-progress">
    <p class="text-sm text-muted-foreground mb-2">${done} of ${total} rows imported</p>
    <progress class="w-full" value="${done}" max="${total}"></progress>
</div>
```

The page renders the fragment once so there is content before the stream connects, and opens the stream with `data-init`:

```html
<div class="card max-w-xl" data-init="@get('/jobs/live')">
    <header><h2>Import job</h2></header>
    <section>
        @template.jobs.progress(done = done, total = total)
    </section>
</div>
```

The handler:

```java
private void live(Context ctx) throws InterruptedException {
    Sse sse = Sse.open(ctx, templates);
    sse.live(Duration.ofMillis(500),
            () -> templates.render("jobs/progress.jte", Map.of("done", job.done(), "total", job.total())));
}
```

Rules for live views:

- Turn on virtual threads (`config.concurrency.useVirtualThreads = true`). Each open stream parks one thread in `Thread.sleep`, which costs nothing on a virtual thread.
- Read a projection the server already keeps, on an interval. 500 ms is enough for a person watching a counter. Add a push mechanism only when polling is measurably too slow.
- Keep the heartbeat. The server learns that a tab closed only when a write fails. A view whose HTML stops changing would otherwise hold its thread forever.
- One live view per page. Wrap everything that moves in one fragment.

## Redirecting from a Datastar request

`ctx.redirect` does not work for a Datastar request. The fetch follows the 302, receives a full HTML page it did not ask for, and the click appears to do nothing. Use `sse.redirect("/login")`, which makes the browser itself navigate.

The common case is an expired session: the user leaves a table open over lunch and then clicks Next. `SessionAuth` in [javalin-app.md](javalin-app.md) handles it.

Do not use the SDK's `ExecuteScript` event for this. Version 1.0.1 sends the script element without a selector, and Datastar 1.0.5 discards it with a `PatchElementsNoTargetsFound` warning in the console.

## Unexpected errors on a Datastar request

A 500 page is useless to a request that expects events, because Datastar would ignore it. The exception handler in [javalin-app.md](javalin-app.md) checks `Sse.isDatastar(ctx)` and patches an error message into `#messages` instead, so the user sees that the click failed.

Every page that issues Datastar actions therefore needs a `<div id="messages">` somewhere. The `fragments/messages.jte` template renders one even when it has nothing to show.

## Checklist when a patch does nothing

1. Does the page load Datastar v1.0.5? Look at the first line of `/js/datastar.js`.
2. Does the rendered HTML say `@get(`, with a single `@`? See the gotchas in [jte-templates.md](jte-templates.md).
3. Does the fragment's root element have an `id`, and does an element with that id exist on the page?
4. Does the response have `Content-Type: text/event-stream`? The browser's network tab shows the raw events. So does `curl -N -b cookies.txt -H 'Datastar-Request: true' http://localhost:8080/items/table`, given a cookie jar from a logged-in session.
5. Is `data-signals` valid? A broken object there stops every expression on the page.
