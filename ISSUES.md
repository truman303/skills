# Agent Skill Issues

## RazorStar Issues

### ISSUE 1: The landing flow is not working correctly

When landing on https://localhost:7264/ we get a 401 and are not redirected to the login page.

### ISSUE 2: Script for post run steps e.g. migrations, seeding, building and running the app

- Starting the development environment (postgres container)
- Creating and running first migration
- Other?

### ISSUE 3: DateTimeOffset confusion

The following error is thrown when trying to save an item:

- ArgumentException: Cannot write DateTime with Kind=Unspecified to PostgreSQL type 'timestamp with time zone', only UTC is supported. Note that it's not possible to mix DateTimes with different Kinds in an array, range, or multirange. (Parameter 'value')

This is because the input dates are Kind=Unspecified.

### Issue 4: Details page links are not working correctly

The details page links should use /Items/Details/{id} instead of /Items/{id}

### Issue 5: Item Edit page does not show existing values on the form

The edit page should show the existing values for the item.

### Issue 6: The guidelines card minimise button closes the card

This is not right, the card should be minimised with just the header visible.

### Issue 7: Include dark mode toggle on header

The header should include a dark mode toggle.

### Issue 8: Add a profile link to the header

The profile link should be a ghost button with the username on the right of the header.

### Issue 9: Spacing between buttons on the item create page

The spacing between the buttons on the item create page is too small or non-existent.

### Issue 10: The workflow should mention the images and theme

The user should be advised to review and change the images and theme in the references folder before creating a new razorstar app. Describe to the use what is required including image size and type. Mention that themes can be copied from [tweakcn](https://tweakcn.com), for example.
