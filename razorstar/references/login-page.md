# Login Page

The login page uses a separate **landing layout** (no sidebar) with a centered card. Cookie authentication with ASP.NET Identity.

## Table of Contents

- [File Checklist](#file-checklist)
- [_LandingLayout.cshtml](#_landinglayoutcshtml)
- [landing.css](#landingcss)
- [LoginViewModel.cs](#loginviewmodelcs)
- [Login.cshtml.cs](#logincshtmlcs)
- [Login.cshtml](#logincshtml)
- [Program.cs Identity Setup](#programcs-identity-setup)
- [AppDbContext Update](#appdbcontext-update)
- [Pages/Index.cshtml.cs (Root Redirect)](#pagesindexcshtmlcs-root-redirect)
- [Dev Seed: Create a Test User](#dev-seed-create-a-test-user)

## File Checklist

```
Pages/
├── Shared/
│   └── _LandingLayout.cshtml       # Centered card layout (no sidebar)
└── Auth/
    ├── Login.cshtml                 # Login form
    └── Login.cshtml.cs              # Cookie auth handler

Features/
└── Auth/
    └── ViewModels/
        └── LoginViewModel.cs        # Form binding model

wwwroot/
└── css/
    └── landing.css                  # Background + frosted card styles
```

## _LandingLayout.cshtml

A minimal layout for unauthenticated pages (login, register, etc.). No sidebar, no app shell — just a centered card over a background image.

```html
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>@ViewData["Title"] - MyApp</title>
    <script type="module" src="~/js/basecoat.all.min.js" defer></script>
    <script nonce>
        (() => {
            try {
                const stored = localStorage.getItem('themeMode');
                const isDark = stored ? stored === 'dark' : matchMedia('(prefers-color-scheme: dark)').matches;
                if (isDark) document.documentElement.classList.add('dark');
                window.initialThemeMode = isDark ? 'dark' : 'light';
            } catch (_) { }
        })();
    </script>
    <link rel="stylesheet" href="~/css/basecoat.css" />
    <link rel="stylesheet" href="~/css/tailwind-output.css" />
    <link rel="stylesheet" href="~/css/theme.css" />
    <link rel="stylesheet" href="~/css/landing.css" />
</head>

<body class="landing-page min-h-screen flex items-center justify-center p-4 m-0">
    <div class="landing-card max-w-md w-full p-8 rounded-xl shadow-2xl">
        @RenderBody()
    </div>

    <script src="~/js/site.js"></script>
    @await RenderSectionAsync("Scripts", required: false)
</body>

</html>
```

**Key differences from `_Layout.cshtml`:**
- No sidebar, no app shell header/footer
- Body uses `flex items-center justify-center` for centering
- Content wrapped in a frosted-glass `.landing-card`
- Includes `landing.css` for background image + card styles
- No DataStar signals in body (login page initializes its own)
- No Datastar JS (login page doesn't need SSE)

## landing.css

Copy from the skill assets folder (`assets/css/landing.css`). Provides background image and frosted-glass card:

```css
body.landing-page {
    background-image: url('/images/key-visual.jpg');
    background-size: cover;
    background-repeat: no-repeat;
    background-position: center center;
    background-attachment: fixed;
}

.landing-card {
    background-color: rgba(239, 239, 239, 0.75);
    backdrop-filter: blur(3px);
    border: 1px solid rgba(255, 255, 255, 0.3);
}

.dark .landing-card {
    background-color: rgba(31, 41, 55, 0.75);
    border: 1px solid rgba(255, 255, 255, 0.2);
}
```

> **Note:** Replace `/images/key-visual.jpg` with the app's background image, or use a CSS gradient as a fallback if no image is available:
> ```css
> body.landing-page {
>     background: linear-gradient(135deg, #1e293b 0%, #334155 50%, #1e293b 100%);
> }
> ```

## LoginViewModel.cs

```csharp
using System.ComponentModel.DataAnnotations;

namespace MyApp.Features.Auth.ViewModels;

public class LoginViewModel
{
    [Required]
    [Display(Name = "Username")]
    public string Username { get; set; } = string.Empty;

    [Required]
    [DataType(DataType.Password)]
    [Display(Name = "Password")]
    public string Password { get; set; } = string.Empty;

    [Display(Name = "Remember me?")]
    public bool RememberMe { get; set; }

    public string? ReturnUrl { get; set; }
}
```

## Login.cshtml.cs

Simplified cookie authentication using ASP.NET Identity's `SignInManager`:

```csharp
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MyApp.Features.Auth.ViewModels;

namespace MyApp.Pages.Auth;

[AllowAnonymous]
public class LoginModel : PageModel
{
    private readonly SignInManager<IdentityUser> _signInManager;
    private readonly ILogger<LoginModel> _logger;

    public LoginModel(
        SignInManager<IdentityUser> signInManager,
        ILogger<LoginModel> logger)
    {
        _signInManager = signInManager;
        _logger = logger;
    }

    [BindProperty]
    public LoginViewModel Input { get; set; } = new();

    public string? ErrorMessage { get; set; }
    public string? SuccessMessage { get; set; }

    public async Task<IActionResult> OnGetAsync(string? returnUrl = null)
    {
        await _signInManager.SignOutAsync();

        Input.ReturnUrl = returnUrl;

        if (TempData["SuccessMessage"] is string successMsg)
        {
            SuccessMessage = successMsg;
        }

        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        if (!ModelState.IsValid)
        {
            return Page();
        }

        var result = await _signInManager.PasswordSignInAsync(
            Input.Username,
            Input.Password,
            Input.RememberMe,
            lockoutOnFailure: false);

        if (result.Succeeded)
        {
            _logger.LogInformation("User {Username} logged in", Input.Username);

            if (!string.IsNullOrEmpty(Input.ReturnUrl) && Url.IsLocalUrl(Input.ReturnUrl))
            {
                return Redirect(Input.ReturnUrl);
            }

            return RedirectToPage("/Dashboard/Index");
        }

        ErrorMessage = "Invalid username or password.";
        return Page();
    }
}
```

## Login.cshtml

```html
@page
@model MyApp.Pages.Auth.LoginModel
@{
    ViewData["Title"] = "Login";
    Layout = "~/Pages/Shared/_LandingLayout.cshtml";
}

<!-- DataStar signals for login form reactivity -->
<div data-signals="{login: {loading: false, showPassword: false}}" style="display: none;"></div>

<!-- Logo -->
<div class="max-w-sm mx-auto mb-5 text-center">
    <img src="~/images/logo.webp" alt="MyApp" class="w-full h-auto object-contain">
</div>

<!-- App Title -->
<div class="text-center mb-6">
    <h1 class="text-xl font-bold text-gray-800 dark:text-gray-100 leading-tight">
        MyApp
    </h1>
</div>

<!-- User Avatar -->
<div class="text-center mb-6">
    <div class="w-24 h-24 mx-auto rounded-full bg-gray-200 dark:bg-gray-600 border-2 border-white/30 dark:border-white/20 opacity-80 flex items-center justify-center">
        <svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="text-gray-600 dark:text-gray-300">
            <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
            <circle cx="12" cy="7" r="4"/>
        </svg>
    </div>
</div>

<!-- Success Message (e.g. after registration) -->
@if (!string.IsNullOrEmpty(Model.SuccessMessage))
{
    <div class="rounded-lg border border-green-200 bg-green-50 p-4 text-green-800 dark:border-green-800 dark:bg-green-900/10 dark:text-green-400 mb-4">
        <div class="flex">
            <svg class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
            </svg>
            <div class="ml-3 text-sm">@Model.SuccessMessage</div>
        </div>
    </div>
}

<!-- Error Messages -->
@if (!string.IsNullOrEmpty(Model.ErrorMessage) || !ViewData.ModelState.IsValid)
{
    <div class="rounded-lg border border-red-200 bg-red-50 p-4 text-red-800 dark:border-red-800 dark:bg-red-900/10 dark:text-red-400 mb-4">
        <div class="flex">
            <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
            </svg>
            <div class="ml-3 text-sm">
                @if (!string.IsNullOrEmpty(Model.ErrorMessage))
                {
                    <p>@Model.ErrorMessage</p>
                }
                @if (!ViewData.ModelState.IsValid)
                {
                    <ul class="list-disc list-inside space-y-1">
                        @foreach (var error in ViewData.ModelState.Values.SelectMany(v => v.Errors))
                        {
                            <li>@error.ErrorMessage</li>
                        }
                    </ul>
                }
            </div>
        </div>
    </div>
}

<!-- Login Form -->
<form method="post" class="space-y-4 relative">
    <input type="hidden" asp-for="Input.ReturnUrl" />

    <!-- Loading Overlay -->
    <div class="absolute inset-0 bg-white/75 dark:bg-gray-800/75 flex items-center justify-center rounded-lg z-10"
         data-show="$login.loading" style="display: none;">
        <div class="flex items-center space-x-2">
            <span class="loading loading-spinner loading-md"></span>
            <span class="text-sm text-gray-600 dark:text-gray-300">Signing you in...</span>
        </div>
    </div>

    <!-- Username -->
    <div class="space-y-1">
        <div class="relative">
            <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="text-gray-400">
                    <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
                    <circle cx="12" cy="7" r="4"/>
                </svg>
            </div>
            <input asp-for="Input.Username"
                   type="text"
                   autocomplete="username"
                   required
                   placeholder="Username"
                   class="input input-bordered w-full pl-10">
        </div>
        <span asp-validation-for="Input.Username" class="text-error text-sm"></span>
    </div>

    <!-- Password -->
    <div class="space-y-1">
        <div class="relative">
            <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="text-gray-400">
                    <rect width="18" height="11" x="3" y="11" rx="2" ry="2"/>
                    <path d="M7 11V7a5 5 0 0 1 10 0v4"/>
                </svg>
            </div>
            <input asp-for="Input.Password"
                   type="password"
                   autocomplete="current-password"
                   required
                   placeholder="Password"
                   class="input input-bordered w-full pl-10 pr-10">
            <!-- Password visibility toggle -->
            <button type="button"
                    class="absolute inset-y-0 right-0 pr-3 flex items-center"
                    data-on-click="$login.showPassword = !$login.showPassword; el.parentElement.querySelector('input').type = $login.showPassword ? 'text' : 'password'">
                <svg data-show="!$login.showPassword" class="h-5 w-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                </svg>
                <svg data-show="$login.showPassword" class="h-5 w-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="display: none;">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L3 3m6.878 6.878L21 21" />
                </svg>
            </button>
        </div>
        <span asp-validation-for="Input.Password" class="text-error text-sm"></span>
    </div>

    <!-- Login Button -->
    <div class="pt-2">
        <button type="submit"
                class="btn btn-primary w-full btn-lg"
                data-on-click__once__passive="$login.loading = true">
            <span data-show="!$login.loading">Log In</span>
            <span data-show="$login.loading" class="flex items-center" style="display: none;">
                <span class="loading loading-spinner loading-sm mr-2"></span>
                Signing in...
            </span>
        </button>
    </div>
</form>
```

## Program.cs Identity Setup

The following must be registered in `Program.cs` (see [project-scaffolding.md](project-scaffolding.md) for full template):

```csharp
// Identity with EF Core stores
builder.Services.AddIdentityApiEndpoints<IdentityUser>()
    .AddEntityFrameworkStores<AppDbContext>();

// Cookie auth configuration
builder.Services.ConfigureApplicationCookie(options =>
{
    options.LoginPath = "/Auth/Login";
    options.LogoutPath = "/Auth/Logout";
    options.AccessDeniedPath = "/Auth/AccessDenied";
    options.ExpireTimeSpan = TimeSpan.FromHours(8);
    options.SlidingExpiration = true;
});

// Razor Pages auth conventions
builder.Services.AddRazorPages(options =>
{
    options.Conventions.AuthorizeFolder("/");
    options.Conventions.AllowAnonymousToPage("/Index");
    options.Conventions.AllowAnonymousToPage("/Auth/Login");
    options.Conventions.AllowAnonymousToPage("/Error");
});
```

And in the middleware pipeline:
```csharp
app.UseAuthentication();
app.UseAuthorization();
app.MapIdentityApi<IdentityUser>();
```

## AppDbContext Update

`AppDbContext` must inherit from `IdentityDbContext<IdentityUser>` instead of plain `DbContext`:

```csharp
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace MyApp.Features.Shared.Database;

public class AppDbContext : IdentityDbContext<IdentityUser>
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        // Apply feature entity configurations
        // builder.ApplyConfiguration(new ItemConfiguration());
    }
}
```

## Pages/Index.cshtml.cs (Root Redirect)

The root `/` page is marked `AllowAnonymous` (via convention in Program.cs) and routes users based on auth state. This avoids a 401 when unauthenticated users land on `/`:

```csharp
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace MyApp.Pages;

public class IndexModel : PageModel
{
    public IActionResult OnGet()
    {
        if (User.Identity?.IsAuthenticated == true)
            return RedirectToPage("/Dashboard/Index");

        return RedirectToPage("/Auth/Login");
    }
}
```

With a minimal `Pages/Index.cshtml`:
```html
@page
@model MyApp.Pages.IndexModel
```

## Dev Seed: Create a Test User

For development, seed a default user on startup. Add to `Program.cs` after `app` is built:

```csharp
// Seed dev user (development only)
if (app.Environment.IsDevelopment())
{
    using var scope = app.Services.CreateScope();
    var userManager = scope.ServiceProvider.GetRequiredService<UserManager<IdentityUser>>();
    var devUser = await userManager.FindByNameAsync("admin");
    if (devUser is null)
    {
        devUser = new IdentityUser { UserName = "admin", Email = "admin@myapp.local" };
        await userManager.CreateAsync(devUser, "Admin123!");
    }
}
```

This gives you a working login out of the box with `admin` / `Admin123!`.
