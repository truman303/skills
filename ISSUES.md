# Agent Skill Issues

## RazorStar Issues

The skill is currently quite opinionated which could make it inflexible. Over time lets whittle it down to the bare essentials and make it more flexible.

### ISSUE 1: The landing flow is not working correctly

When landing on root https://localhost:7264/ we get a 401 and are not redirected to the login page.

### ISSUE 2: Script for post run steps e.g. migrations, seeding, building and running the app

- Starting the development environment (postgres container)
- Creating and running first migration
- Other?

### ISSUE 3: DateTimeOffset confusion

The following error is thrown when trying to save an item:

- ArgumentException: Cannot write DateTime with Kind=Unspecified to PostgreSQL type 'timestamp with time zone', only UTC is supported. Note that it's not possible to mix DateTimes with different Kinds in an array, range, or multirange. (Parameter 'value')

This is because the input dates are Kind=Unspecified on a specific input DateTime field. The system uses DateTimeOffset for all genuine date time values. Where only a date is needed, use `DateOnly` instead of `DateTime`. Please update the skill to highlight this. Also include it in the Gotchas section at the end of the skill.

### Issue 4: Details page links are not working correctly

The details page links were broken. I had to change this `/Items/{id}` to this `/Items/Details/{id}`, since thats how the page setup is. Please fix this in the skill.

### Issue 5: Item Edit page does not show existing values on the form

The edit item page does not show the existing values for the item.

### Issue 6: The guidelines card minimise button closes the card

This is not right, when a card is minimised, just the header and the minimise/maximise button should be visible.

### Issue 7: Include dark mode toggle on header

The header should include a dark mode toggle out of the box.

### Issue 8: Add a profile link to the header

The profile link should be a ghost button with the username on the right of the header.

### Issue 9: Spacing between buttons on the item create page

The spacing between the buttons on the item create page is too small or non-existent.

### Issue 10: The workflow should mention the images and theme

The user should be advised to review and change the images and theme in the references folder before creating a new razorstar app. Describe to the use what is required including image size and type. Mention that themes can be copied from [tweakcn](https://tweakcn.com), for example.

### Issue 11: The skill should support side menu or top menu

The skill should support both side menu and top menu. The user should be able to choose which menu they want to use during the build process.
