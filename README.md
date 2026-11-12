# API-to-Cloud Trivia Showdown

CSC 4360 In-Class Activity #15

# Setup

To run this project locally, use the following commands:

```bash
flutter pub get
flutter run -d emulator-5554
```

# Features

- Fetches 5 easy multiple-choice questions from Open Trivia DB
- Checks HTTP status and API `response_code` before using results
- Cleans encoded entities (`&quot;`, `&#039;`, `&amp;`, etc.)
- Shuffles answer options
- Shows loading, error, question, and results states
- Enforces one answer per question
- Green correct / red incorrect feedback
- Prevents double scoring
- Final score and replay
- Score-sync action

# Score-sync behavior

`_leaderboardEndpoint` is `null` in this submission, so the app runs the classroom simulation. The button reads "Simulate Score Sync" and the snackbar states that no backend request was sent. No local data is presented as a shared leaderboard.

If an instructor endpoint were configured, the app would POST a JSON payload (`score`, `total`, `roundId`, `submittedAt`, `source`) and only report success on a 2xx response.

# Evidence

Screenshots in `evidence/`:

- 01_loading.png
- 02_question.png
- 03_correct_green.png
- 04_incorrect_red.png
- 05_final_score.png
- 06_sync_snackbar.png
- 07_error_state.png

# Optional local storage

Local storage was not implemented because it is optional for this activity. The app does not present local state as a shared leaderboard.

