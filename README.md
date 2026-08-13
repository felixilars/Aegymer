# Aegymer

Aegymer is a fitness and nutrition tracking app built with Flutter. It helps users log workouts, monitor progress over time, and plan meals around their calorie and macro goals. The app turns your activity and food input into practical recommendations for reaching your training and body goals.

## Table of Contents

- [Demo](#demo)
- [Getting Started](#getting-started)
- [How to use each page](#how-to-use-each-page)
- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
- [Contributing](#contributing)

## Getting Started

Follow these steps to get the app running locally:

1. Clone the repository:

```bash
git clone https://github.com/felixilars/Aegymer.git
```

2. Open the Flutter app directory:

```bash
cd Aegymer/flutter_application_1
```

3. Install dependencies:

```bash
flutter pub get
```

4. Run the app:

```bash
flutter run
```

## How to use each page

### 1. Home page

<img src="../screenshots/homepage.gif" alt="Home page walkthrough" width="260" />

The Home page is your daily dashboard. It gives you a quick overview of your fitness routine and your consistency.

What you can do here:

- Check your current workout streak and weekly target.
- Swipe through summary cards for your progress overview.
- View recent workout sessions at a glance.
- Tap Start Workout to begin a training session.
- Tap the profile icon in the app bar to update your body metrics, activity level, or nutrition target.
- Pull down to refresh the page and update the latest data.

How to use it:

1. Open the app and land on the Home tab.
2. Review your streak, weekly goal, and recent sessions.
3. If you want to train, tap Start Workout.
4. If your goals change, open your profile and update your details.

### 2. Meals page

<img src="../screenshots/meal.gif" alt="Meals page walkthrough" width="260" />

The Meals page helps you plan food around your goals and current meal context.

What you can do here:

- Pick the meal you are currently planning, such as breakfast, lunch, dinner, or snacks.
- See how many calories and macros are still remaining.
- Browse recommended foods based on your goals and food preferences.
- Search for foods by name.
- Add foods to your meal by choosing the portion size.
- Edit or remove foods you already logged.

How to use it:

1. Go to the Meals tab.
2. Select the meal you want to track.
3. Review the remaining calories and macros.
4. Add a recommended food or search for your own food.
5. Choose the amount in grams and confirm.
6. Repeat for other foods until your meal is balanced.

### 3. Workout page

<img src="../screenshots/workout_session.gif" alt="Workout page walkthrough" width="260" />

The Workout page is where you record and manage your actual training.

What you can do here:

- Choose a saved routine or start a freestyle workout.
- Create a new routine by selecting exercises and saving it.
- Edit or delete an existing routine if needed.
- Start a timer for the training session.
- Add sets for each exercise and enter weight, reps, distance, or duration.
- Track different training styles such as weighted lifts, bodyweight exercises, or cardio.
- Save the session after finishing the workout.

How to use it:

1. Open the Process tab.
2. Select a workout routine or tap Start Free Style.
3. Add the exercises you want to complete.
4. Fill in each set with the correct values.
5. Use the timer to monitor session time.
6. When finished, complete the workout and save the log.

### 4. Progress page

<img src="../screenshots/progress_chart.gif" alt="Progress page walkthrough" width="260" />

The Progress page shows how your training is improving over time.

What you can do here:

- View your best lifts and workout stats.
- Switch between Exercise, Muscle, and Day views.
- Compare performance across different exercises or muscle groups.
- Track trends over time with charts.
- Review your total workouts and trained movements.

How to use it:

1. Open the Progress tab.
2. Choose whether you want to view data by exercise, muscle group, or day.
3. Pick the specific exercise or muscle group you want to inspect.
4. Review the chart and summary cards to see your training trend.
5. Use this data to adjust your future workouts and goals.

## Features

- Personalized fitness and nutrition tracking.
- Workout streak tracking and weekly goal setting.
- Meal recommendations based on remaining calories and macros.
- Food search and meal logging.
- Workout routine creation and editing.
- Exercise tracking with sets, reps, weight, distance, and time.
- Training progress analytics with charts and PR summaries.
- Local profile management for your body stats, activity level, and goals.

## Installation

1. Make sure Flutter and Dart are installed on your machine.
2. Open the project in your preferred IDE.
3. Run:

```bash
flutter pub get
```

4. Connect a simulator or device, then launch:

```bash
flutter run
```

## Usage

1. Create your profile on first launch so the app can calculate your calorie and macro targets.
2. Use the Home page to check your status and start workouts.
3. Track meals in the Meals page.
4. Log workouts in the Process page.
5. Review your improvement in the Progress page.
6. Update your profile whenever your body metrics or goals change.

## Contributing

If you want to improve the app, feel free to fork the project and submit a pull request with your changes.

