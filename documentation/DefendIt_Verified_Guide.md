# DefendIt System Guide and Documentation
Thesis Consultation and Milestone Tracker

## 1 Core Purpose and Utility

### 1.1 Introduction and Core Purpose

DefendIt is a thesis consultation and milestone tracker for fourth-year Computer Engineering students and faculty thesis advisers. It connects student groups with their assigned adviser through a shared workflow for proposals, consultations, feedback, and capstone deliverables. Its primary mission is to make advising organized, actionable, and visible: students can identify their next responsibilities, while advisers can review work and communicate decisions within the same application.

### 1.2 Rationale and Problem Addressed

Traditional advising often depends on scattered chat messages, separate schedules, and personal notes. Consultation notes can be lost, requested revisions forgotten, and responsibilities left unclear. Without a common progress record, students and advisers may struggle to distinguish ongoing work from completed tasks or submissions still awaiting approval.

DefendIt addresses these issues by connecting consultation notes to assignable action items and milestone tasks to adviser review. Shared status, deadlines, and feedback help groups follow through between meetings. Task completion remains distinct from adviser approval, providing a clearer account of capstone progress.

### 1.3 Main Feature Set

Google Sign-In authenticates users, while Student and Adviser access controls present relevant workflows. Student leaders create groups and share teammate codes; members submit title proposals for adviser approval, polishing, or rejection. Advisers publish consultation slots, and members book their group's adviser. Meeting records preserve notes and action items with optional roster assignees and due dates.

Six standardized milestones cover title approval, Chapters 1–3, proposal defense, and final defense. Students manage tasks and submit completed milestone work; advisers approve or request revision. Selected records use local SQLite storage and an outbox that synchronizes with Firestore after connectivity returns. This supports continued local work, while booking and other transactional operations require a connection.

### 1.4 Topic Exclusivity Compliance

DefendIt's distinct domain is Automated Capstone Advising, Consultation Scheduling, and Milestone Workflow Management. Its combined proposal review, consultation follow-through, and milestone approval workflow defines the topic and primary feature set for compliance with Requirement 2e. Automation supports coordination and tracking; faculty advisers retain academic decisions.

Compliance requires registering this combined concept through the academic first-come approval process and confirming that no other group has the same topic, core concept, or primary feature set. The app does not verify exclusivity automatically; final confirmation rests with the approving academic authority.

## 2 Target User Personas

### Roles and permissions

Student Leader and Teammate share `UserRole.student`; the other role is `adviser`. `leaderUid` identifies the creator, `roster.first` displays the leader, and `memberUids` authorizes student membership.

| Persona | Main responsibility | Available actions |
|---|---|---|
| Student Leader | Establish the group. | Register; create roster; share code; use member features. |
| Teammate | Perform group work. | Join; manage titles and tasks; book; read notes; toggle action items. |
| Adviser | Guide accepted groups. | Claim code; accept up to four groups; publish slots; maintain consultation records; review work. |

### Student Leader flow

1. Sign in, choose Student, register a number, and leave teammate code empty.
2. Create the group with name, section, topic, and two to five distinct roster names, leader first. Share the code; roster names alone do not grant account access.
3. Submit proposals, book after adviser acceptance, complete assigned work, and submit eligible milestones.

### Teammate and adviser flows

A teammate joins during onboarding or from Groups; membership checks reject a second group. Failed joining after profile registration produces retry guidance. Advisers claim issued codes, preview Requests, accept groups transactionally, then publish slots, open consultations from Availability, and review work. Consultation methods rely on UI restrictions and backend rules rather than actor guards.

===PAGE===

## 3 UI UX and Wireframe Specifications

### Custom visual identity

DefendIt uses a teal, forest green, and warm amber identity with pale sage backgrounds. Its custom Material 3 theme defines typography, cards, status chips, action sheets, and dashboard hierarchy. The legacy identifiers `indigo`, `indigoDark`, and `indigoTint` map to the teal values below; they do not describe the current hues.

| Visual role and code token | Exact hex value | Application |
|---|---|---|
| Primary teal `indigo` | #176B63 | Buttons, focused inputs, selected labels. |
| Forest teal `indigoDark` | #103C3B | Dark emphasis, snackbars, shadows. |
| Pale sage `indigoTint` | #E3F1ED | Selection indicators and progress tracks. |
| Warm amber `amber` | #E9B65E | Secondary emphasis and explicit action accents. |
| Background `paper` / `surface` | #F4F7F5 / #FFFFFF | Screen backgrounds / cards and inputs. |
| Text `ink` / `muted` | #18332F / #60756F | Main text / secondary labels. |
| Divider `border` | #DCE6E0 | Borders and dividers. |
| Feedback `success` / `error` | #287B57 / #C34848 | Successful states / errors. |

Application text uses Inter through `google_fonts`: headings 30 and 22 logical pixels, titles 16, body 14, captions 12, and buttons 15. Hardcopy text uses Century Gothic at 11 pt. Login displays DefendIt; `MaterialApp.title` and `Strings.appName` retain ThesisTrack.

### Layout and interaction rules

The shell has Today, Schedule, Groups, and Progress destinations. `IndexedStack` keeps their widget state while switching tabs. Schedule presents Availability to advisers and booking controls to students. Group and milestone details open through `Navigator` routes; creation and review forms use scrollable bottom sheets with keyboard-aware bottom padding.

Global styling uses 20-pixel card radii, 14-pixel input and primary-button radii, and 28-pixel upper sheet corners. Primary buttons have a minimum height of 52; app and navigation bars use 72. Status chips combine words and icons with color. Loading, empty, and error views give distinct feedback; busy buttons prevent repeated submission.

### Essential form specifications

Group name accepts 2–40 characters, section 2–30, thesis topic 5–160, and roster names 2–60. Title proposals require a 5–150-character title, 10–500-character description, and 10–400-character purpose. Task and action-item titles accept 3–120 characters. Whitespace is trimmed during validation or saving.

Adviser title feedback is required for Needs polish and Rejected decisions. Approval comments are optional. Destructive actions such as deleting tasks or canceling bookings request confirmation. Keep these controls and explanations visible in the corresponding layouts rather than exposing unavailable actions to the wrong role.

===PAGE===

### Wireframe layouts and screen behavior

Read each column vertically. Brackets indicate controls; regions show content order rather than exact dimensions. Apply teal controls, sage selection fills, white surfaces, and amber accents throughout.

| Login and onboarding | Today | Schedule |
|---|---|---|
| DefendIt identity | Greeting • Account • Sync | Schedule or Availability |
| Forest teal gradient and introduction | Teal consultation card on sage header | Available / My bookings for students |
| [White Google sign-in button] | Groups • Booked • Open slots | Day heading and time range |
| [Adviser] [Student] on white card | Needs attention | Open or booked status |
| Code or student number fields | Coming up bookings | [Book] [Cancel] or adviser [Add slot] |
| [Continue] • Error message | Today / Schedule / Groups / Progress | Today / Schedule / Groups / Progress |

| Groups and title details | Progress and milestone detail | Consultation |
|---|---|---|
| Group • Topic • Adviser | Group progress / Milestone name | Session details and roster |
| Section • Roster • Teammate code | Status • Date • Feedback | Meeting notes |
| Proposed title • Status | Tasks completed / Total tasks | Adviser [Save notes] |
| Description • Purpose | Team workload | Action item • Assignee • Due |
| Adviser feedback | Task title • Assignee • Due | [Done] checkbox for both roles |
| [Add] [Revise] or [Review] | [Add task] [Submit] or adviser [Review] | Adviser [Add] [Delete] item |

Students use day-grouped Available and My bookings lists; advisers publish slots and open booked consultations from Availability. Student Progress opens the group's milestone board directly; advisers first choose a group. The corresponding screen specifications retain the same hierarchy on empty, loading, and error states.

Login uses #092F30 → #154C48 → #092F30, with #ECCB91 accent text and #B7CDC5 secondary text. Onboarding uses #E2EEE8 → #F9FAF6 → #EDE9DC; Today uses #DCEDE5 → #F0F5EE → #E8EDE1. The consultation hero uses #103C3B → #216F62. Review and polish indicators use #B7791F. These screen-specific colors supplement the shared palette.

Today computes attention items from SQLite. Students see revisions, title polish, overdue work, and ready submissions. Advisers see pending reviews before overdue work. Entries link to their corresponding records.

### Milestone workflow

The six seeded milestones are Title approval; Chapter 1: Introduction; Chapter 2: Review of Related Literature; Chapter 3: Methodology; Proposal defense; and Final defense. Their positions define display order. Approval of one milestone does not automatically unlock another, and approving a title does not automatically approve the Title approval milestone.

Students move `notStarted` to `inProgress`, and `inProgress` to `forReview`. Adding the first task starts a milestone automatically. Submission requires at least one task and all tasks completed. Students can withdraw `forReview` to `inProgress`; `needsRevision` can return to work or be resubmitted when eligible.

Only the assigned adviser can move `forReview` to `approved` or `needsRevision`. Revision feedback is required; its UI requires at least five characters. Tasks lock during review and after approval. Overall progress averages milestone completion: approved counts as 1; otherwise completed tasks divided by total tasks counts, with zero for no tasks. A 100 percent task-based progress display does not by itself mean adviser approval.

===PAGE===

## 4 System Architecture and Tech Stack

### Three tier structure

| Tier | Components | Responsibility |
|---|---|---|
| Presentation | `features/`, `core/widgets/`, theme, router, `AuthProvider`, `TodayController`. | Render role-specific screens, validate inputs, observe streams, and display results. |
| Repository | Auth, Group, Slot, Consultation, Title, Milestone, and Attention repositories. | Apply workflow rules and choose local or remote persistence. |
| Persistence and sync | `AppDatabase`, `SyncService`, Firebase Auth, Cloud Firestore. | Store account-specific local records, queue writes, authenticate identities, and distribute remote changes. |

`main.dart` initializes Flutter bindings and Firebase before creating `MultiProvider`. Providers supply shared repositories and database services. `AuthProvider`, `TodayController`, and `SyncService` use `ChangeNotifier`; database-backed screens use streams, commonly through `StreamBuilder`. `app.dart` creates the router once and applies `AppTheme.light` through `MaterialApp.router`.

### Data flow and synchronization

Local workflow: Screen → Repository → SQLite transaction containing the row change and outbox operation → local change notification → refreshed screen. The repository then calls `SyncService.flush()`. This keeps a committed local edit available while its remote upload remains pending.

Remote workflow: Outbox ordered by `seq` → Firestore merge or delete → successful operation removed from outbox. Firestore listeners → model conversion → SQLite replacement or deletion → local notification. Advisers subscribe to consultations and action items by `adviserUid`; students subscribe by group. Both subscribe to titles, milestones, and tasks under their groups.

The engine skips incoming changes for documents with pending local operations. Otherwise, an existing row with a newer `updatedAt` is retained. Updates use client millisecond timestamps and partial merge payloads. This is a basic conflict policy; it does not provide revision history, guaranteed conflict reconciliation, or server-clock ordering.

Connectivity changes trigger flushing; the sync chip also offers manual retry. Each push times out after 12 seconds, and failure leaves the operation queued. Connectivity reports a network connection, not confirmed Firebase reachability. Group operations, slot mutations, registration transactions, initial consultation creation, and legacy milestone seeding require online service access.

### Declared dependencies

`pubspec.yaml` requires Dart `^3.12.2`. Core constraints are `firebase_core ^4.15.0`, `firebase_auth ^6.7.0`, `google_sign_in ^7.2.0`, `cloud_firestore ^6.10.0`, `sqflite ^2.4.4+1`, `provider ^6.1.5+1`, and `go_router ^17.5.0`. Supporting packages include `connectivity_plus ^7.3.2`, `google_fonts ^8.2.1`, `uuid ^4.6.0`, `path ^1.9.1`, `intl 0.20.2`, and `table_calendar 3.2.1`. Retain `pubspec.lock` for resolved application dependency versions.

===PAGE===

## 5 Authentication and Session Management

### Google sign in

`AuthRepository` initializes `GoogleSignIn.instance` with `Strings.webClientId`, then calls `authenticate()`. The returned ID token becomes a `GoogleAuthProvider` credential passed to `FirebaseAuth.signInWithCredential()`. No password login or phone-number authentication is implemented; Google satisfies the permitted authentication choice.

`AuthProvider` listens to Firebase `authStateChanges()`, fetches `users/{uid}`, and determines whether onboarding is needed. A missing profile is initialized in memory from Google's display name, email, and photo. Authentication errors appear through `errorMessage`; cancellation currently produces an `AuthFailure` message mentioning cancellation or SHA-1 configuration.

### Registration checks

Students enter a number normalized to ten digits with a dash after the first four. The exact validator is `^20\d{2}-\d{6}$`; `2022-102420` is a valid example. Normalization removes nondigits and caps input at ten digits. A Firestore transaction claims `studentNumbers/{number}` and saves the student profile. Another UID cannot claim an existing number. This enforces account uniqueness, not independent verification of university enrollment.

Adviser registration normalizes the supplied code to uppercase and removes whitespace. Empty codes and codes containing `/` are rejected. A transaction reads `adviserCodes/{code}`, checks its claim, updates `claimedByUid` and `claimedAt`, and saves the adviser profile with `adviserCode`. A different UID cannot reuse a claimed code; the same UID is accepted. Codes must already exist in Firestore; there is no code-issuance screen.

### Session states and routing

| AuthStatus | Route | Meaning |
|---|---|---|
| loading | `/splash` | Waiting for authentication and profile resolution. |
| signedOut | `/login` | No usable application session, or profile loading failed. |
| needsRole | `/onboarding` | Google identity exists but the profile has no role. |
| ready | `/home` | Profile has a recognized Student or Adviser role. |

The router uses `refreshListenable: auth` to reevaluate redirects. Firebase supplies session persistence; no custom token table or inactivity timer is implemented. The onboarding UI presents role selection as a one-time choice, and no role-change screen is provided.

Entering `MainShell` starts sync and opens `thesistrack_{uid}.db`. Leaving the shell stops subscriptions and closes the database. Sign-out signs out of Google and Firebase. Local files remain on the device, separated by UID; sign-out does not delete queued work or encrypt the database. On return, that account can resume its stored work. Confirm pending changes synchronize before treating another device as fully current.

===PAGE===

## 6 Database Schema and CRUD Mapping

### Firestore identity and coordination records

Firestore document IDs identify records; most model payloads omit `id`, while `AppUser` stores `uid` explicitly. The following are exact collection paths and written field names. A question mark denotes an optional or nullable application value. Registry and profile timestamps use server timestamps; other date fields use integer epoch milliseconds.

| Document path | Exact fields and types |
|---|---|
| `users/{uid}` | `uid`, `name`, `email`: string; `photoUrl`, `role`, `studentNumber`: string?; repository fields `createdAt`: timestamp, `adviserCode`: string when registered as adviser, `adviserGroupCount`: integer when groups are accepted. |
| `studentNumbers/{number}` | `uid`: string; `createdAt`: timestamp. Document ID is the normalized student number. |
| `adviserCodes/{code}` | Registration reads/writes `claimedByUid`: string? and writes `claimedAt`: timestamp. Code creation metadata is not defined in `lib/`. |
| `groups/{groupId}` | `name`, `thesisTitle`, `code`: string; `memberUids`, `roster`: string lists; `memberNames`: UID-to-name map; `createdAt`: integer; `section`, `leaderUid`, `adviserUid`, `adviserName`: string?. |
| `slots/{slotId}` | `adviserUid`, `adviserName`, `status`: string; `startsAt`, `durationMins`, `createdAt`: integer; `bookedGroupId`, `bookedGroupName`, `bookedByUid`, `bookedByName`: string?. |

New groups use the creator's UID as their document ID. Group creation writes the group and its six milestone documents in one transaction. `memberUids` is the account access list; `memberNames` maps signed-in members; `roster` is the official list of names. Joining changes account membership without changing the roster. Assignees are roster names rather than account UIDs.

Slots use Firestore-generated IDs and `open` or `booked` status. Booking transactionally checks availability, future start time, membership, and adviser matching before setting booking fields. Cancellation restores `open` and clears booking fields. An adviser deletes only their own open slots; booked slots must be canceled first. Publishing rejects overlap with the adviser's existing slots through a preliminary query.

Profiles, groups, codes, number claims, and slots have no dedicated SQLite tables. Their repositories use Firestore directly. Firestore SDK caching should not be confused with the application's explicit SQLite outbox. The current source provides no group deletion or editing workflow, and no profile-management CRUD screen.

===PAGE===

### Firestore records mirrored in SQLite

Each mirrored SQLite table adds `id TEXT PRIMARY KEY` to the Firestore payload. Strings become TEXT and numeric date fields become INTEGER. `done` is a Firestore boolean converted to SQLite 0 or 1. `consultations.roster` is a Firestore list serialized as JSON TEXT locally. Nullable fields below remain nullable in SQLite.

| Firestore path → SQLite table | Exact payload fields |
|---|---|
| `consultations/{id}` → `consultations` | Strings: `groupId`, `groupName`, `adviserUid`, `adviserName`, `notes`. Integers: `startsAt`, `durationMins`, `createdAt`, `updatedAt`. String list: `roster`. ID equals the booked slot ID. |
| `actionItems/{id}` → `action_items` | Strings: `consultationId`, `groupId`, `groupName`, `adviserUid`, `title`. Nullable string: `assignee`. Nullable integers: `dueAt`, `doneAt`. Boolean: `done`. Integers: `createdAt`, `updatedAt`. |
| `groups/{groupId}/titles/{id}` → `title_ideas` | Strings: `groupId`, `title`, `description`, `purpose`, `status`, `createdByUid`, `createdByName`. Integers: `createdAt`, `updatedAt`. Nullable strings: `comment`, `reviewedByName`. Nullable integer: `reviewedAt`. |
| `groups/{groupId}/milestones/{id}` → `milestones` | Strings: `groupId`, `slug`, `title`, `status`. Integers: `position`, `updatedAt`. Nullable integer: `dueAt`. Nullable strings: `comment`, `updatedByName`. ID is `{groupId}_{slug}`. |
| `groups/{groupId}/tasks/{id}` → `milestone_tasks` | Strings: `groupId`, `milestoneId`, `title`, `createdByName`. Nullable strings: `assignee`, `doneByName`. Nullable integers: `dueAt`, `doneAt`. Boolean: `done`. Integers: `createdAt`, `updatedAt`. |

Title, task, and action-item IDs are generated with UUID v4. A consultation copies the group's current roster when initialized; later roster changes do not automatically rewrite the consultation snapshot. There are no declared SQLite foreign keys or cascading deletes. Relationships are maintained through identifiers and repository behavior.

### Local queue and schema lifecycle

`outbox` contains `seq INTEGER PRIMARY KEY AUTOINCREMENT`, required TEXT fields `collection`, `docId`, and `op`, nullable `data TEXT`, and required `createdAt INTEGER`. `data` stores a JSON payload; `op` is `upsert` or `delete`. `collection` can contain a nested group path. This local queue is not a Firestore collection.

The database is version 4. Version 2 introduces `title_ideas`, version 3 adds `milestones`, and version 4 adds `milestone_tasks`. Explicit indexes are `idx_items_consultation`, `idx_titles_group`, `idx_milestones_group`, and `idx_tasks_milestone`. Account switching opens a separate database file rather than mixing rows under one shared account cache.

===PAGE===

### CRUD rules and lifecycle

| Record | Create and read | Update and delete |
|---|---|---|
| Title idea | Members create pending ideas; local reads sort oldest first. Unassigned-group preview reads Firestore directly. | Members edit pending or needsPolish records, resetting review fields. They delete any nonapproved title. Assigned adviser reviews. |
| Consultation | Adviser opens a booked slot; an existing remote record is reused or a new local record is queued. | Adviser UI saves notes. No consultation deletion method is provided. |
| Action item | Adviser UI adds title, optional roster assignee, and optional due date. | Both roles toggle done; adviser UI deletes. No title-edit workflow exists. |
| Milestone | Six defaults are created with the group; older empty groups can be seeded online. | Students change permitted work states; adviser reviews and sets dates. No custom milestone creation or deletion UI exists. |
| Milestone task | Student members add tasks under editable milestones; reads show unfinished tasks first. | Members edit, toggle, and delete while unlocked. Completion records `doneAt` and `doneByName`; reopening clears both. |

Title status values are `pending`, `approved`, `needsPolish`, and `rejected`. Reviewing a title records the comment, reviewer name, review time, and update time. Editing a permitted title clears its previous review. Approval does not update `groups.thesisTitle`, so the group's displayed topic and approved proposal are separate records.

Milestone slugs are `title_approval`, `chapter_1`, `chapter_2`, `chapter_3`, `proposal_defense`, and `final_defense`. Status values are `notStarted`, `inProgress`, `forReview`, `needsRevision`, and `approved`. No separate approval-history collection is implemented. Current status and feedback represent the stored decision.

### Consistency and access considerations

Local workflow writes and their queue entries share a SQLite transaction. Remote replay uses `set(..., SetOptions(merge: true))` or document deletion. Merge payloads limit accidental overwrites of unrelated fields, such as replacing a task title when only completion changed. Success clears the corresponding queue row; failure retains it.

Firestore rules must validate membership, assigned adviser identity, protected fields, registration claims, and accepted-group limits. Comments in the repositories refer to rule enforcement, but `lib/` does not contain a deployable rules definition. The supplied `firebase.json` declares Flutter configuration rather than a Firestore rules deployment target. Backend permissions therefore require separate configuration and integration testing.

The sync service ignores several listener and local-apply errors, so a quiet screen does not prove remote synchronization succeeded. It exposes `lastError`, but the chip primarily reflects connectivity, pending count, and active flushing. Verify the second device or Firestore document when checking successful propagation. Do not report an offline edit as remotely approved until that state reaches the backend.

===PAGE===

## 7 Setup and Build Instructions

### Development environment

1. Install Flutter with a bundled Dart version satisfying `^3.12.2`, Android Studio, Android SDK tools, and a compatible Java environment. The Android project targets Java and Kotlin JVM 17. Add Flutter to PATH and run `flutter doctor` to identify missing tools and licenses.
2. Open the project root containing `pubspec.yaml`. Run `flutter pub get`, then `flutter analyze`. Keep the existing application lockfile unless intentionally changing dependencies. The package name is `thesis_track`, and the declared version is `1.0.0+1`.
3. Start an Android emulator or connect a device with USB debugging enabled. Run `flutter devices` and `flutter run`. Android is the current practical verification target for the native sign-in and sqflite path.

### Firebase configuration

4. Obtain authorized access to Firebase project `thesis-track-6a918`, or configure a separate project for development. Enable Google under Authentication sign-in providers and create Cloud Firestore. The current Android application ID is `com.example.thesis_track`.
5. Register the Android app and its signing-certificate fingerprints. From `android`, run `.\gradlew signingReport` in PowerShell to inspect configured signing certificates. Configure the applicable fingerprints for debug and release builds. Keep the matching `google-services.json` in `android/app/`.
6. Install the Firebase CLI and FlutterFire CLI if absent: `npm install -g firebase-tools`, followed by `dart pub global activate flutterfire_cli`. Run `firebase login`, then `flutterfire configure --project=thesis-track-6a918 --platforms=android,web` from the project root when regenerating this configuration.
7. Confirm `lib/firebase_options.dart` matches the chosen project and `Strings.webClientId` matches its Google Web OAuth client ID. Enable and test the deployed Firestore rules. Pre-create adviser-code documents for issued codes, leaving `claimedByUid` null or absent until registration claims them. No administrator credential belongs in the app.

### Verification and APK generation

8. Test Google sign-in, student and adviser onboarding, group acceptance, booking, title review, and milestone submission on connected accounts. Repeat relevant local edits offline, then reconnect and verify remote propagation. Run `flutter test` after adding applicable automated tests; `flutter_test` is declared, but a dependency declaration does not prove test coverage.
9. Generate the Android package with `flutter build apk --release`. The default output is `build/app/outputs/flutter-apk/app-release.apk`. Install for device verification with `adb install -r build/app/outputs/flutter-apk/app-release.apk`.

The current release build uses the debug signing configuration. Configure a proper release keystore before distribution. iOS, macOS, Windows, and Linux Firebase options currently throw `UnsupportedError`. Web options exist, but SQLite has no web adapter and sign-in uses the native authentication path. Additional configuration and compatible storage and sign-in implementations are needed before claiming cross-platform execution.

===PAGE===

## 8 Test Cases Document

### Test preparation and recording

Use separate Google accounts for a leader, teammate, and adviser, plus one unclaimed adviser code and distinct valid student numbers. Use two devices or sessions for shared-data checks. Create a two-member roster, accept the group, and publish a future slot. Record actual result, pass or fail, tester, and date separately. The tables specify expected behavior, not completed execution results.

| Test ID | Feature | Input or action | Expected result |
|---|---|---|---|
| UI01 | Custom navigation | Open each bottom destination. | Correct role-specific content appears; tab state is retained. |
| UI02 | Form validation | Submit a title shorter than five characters. | Inline validation blocks saving. |
| UI03 | Empty state | Open Groups before joining or creating. | Guidance and applicable create or join controls appear. |
| AU01 | Google authentication | Sign in with a valid Google account. | Firebase session starts; profile determines onboarding or home. |
| AU02 | Sign-in cancellation | Cancel the Google account flow. | User remains outside home and receives the implemented error message. |
| AU03 | Student number | Register `2022-102420`; then try another account with the same number. | First succeeds; second is rejected without taking ownership. |
| AU04 | Adviser code | Claim an unused issued code; reuse it with another UID. | First adviser registers; second claim fails. |
| AU05 | Session and sign-out | Relaunch after sign-in, then sign out. | Session resolves through Firebase; sign-out routes to login and stops local sync. |
| GR01 | Group creation | Create a valid group with two distinct roster names. | Group and six default milestones are created; creator is leader. |
| GR02 | Group joining | Teammate joins with a valid six-character code. | UID and display name join membership; official roster stays unchanged. |
| GR03 | Adviser capacity | Adviser with four accepted groups attempts another acceptance. | Requests are hidden at capacity; repository rejects extra acceptance. |
| SL01 | Slot booking | Member books a future open slot from their adviser. | Slot becomes booked with group and actor fields. |
| SL02 | Slot collision | Two members attempt the same open slot. | One booking succeeds; the other observes an unavailable or booked slot. |
| SL03 | Slot update and delete | Cancel a future booking, then adviser deletes the open slot. | Booking fields clear; slot document is removed. |
| SL04 | Slot creation | Publish a future slot, then an overlapping slot. | First is created; overlap is rejected. |

For authentication tests, inspect the resulting profile and claim documents as well as the visible screen. For booking tests, confirm the backend slot state from both accounts. A successful button response alone is insufficient evidence of shared-data correctness.

===PAGE===

### CRUD and offline synchronization tests

| Test ID | Feature | Input or action | Expected result |
|---|---|---|---|
| DB01 | Title create and read | Member submits a valid title, description, and purpose. | Pending title appears locally and in its Firestore subcollection. |
| DB02 | Title review and update | Adviser chooses Needs polish with feedback; member revises. | Feedback first appears; revision resets status to pending and clears review fields. |
| DB03 | Title delete guard | Delete a pending title; attempt deletion after approval. | Pending record is removed; approved title deletion is unavailable or rejected. |
| DB04 | Consultation notes | Adviser opens booked slot and saves notes. | Consultation uses slot ID; students can read notes after sync. |
| DB05 | Action-item CRUD | Adviser adds item; member toggles it; adviser deletes it. | Item appears, completion updates, then record disappears locally and remotely. |
| MS01 | Task CRUD | Add, edit, complete, reopen, and delete an editable task. | Changes persist; reopening clears completion metadata. |
| MS02 | Submission gate | Submit with zero tasks, incomplete tasks, then all tasks done. | First two attempts are blocked; complete nonempty list permits forReview. |
| MS03 | Adviser approval | Approve a submitted milestone. | Status becomes approved; task editing locks. |
| MS04 | Revision feedback | Request revision without feedback, then enter valid feedback. | Empty feedback is blocked; valid revision unlocks student task work. |
| SY01 | Offline persistence | After initial sync, disable networking and edit a task; restart app. | Local edit and queued operation remain available for the same account. |
| SY02 | Reconnect upload | Restore networking after offline edits. | Queue drains after successful uploads; second account receives changes. |
| SY03 | Failed upload | Interrupt service access while a write is queued. | Operation remains queued; later retry can complete it. |
| SY04 | Offline restrictions | Offline, try booking or first-time consultation creation. | Connection guidance appears; operation is not reported as completed. |
| SY05 | Account isolation | Sign out, sign into another account, then return. | Accounts use different SQLite files; original local data remains with its UID. |

### Acceptance and maintenance

Test backend rejection of unauthorized consultation edits and role claims. Verify each claimed platform, record failures as defects, and recheck affected workflows after repository, schema, or sync changes.

Implementation references: `lib/data/models/`, `lib/data/repositories/`, `lib/data/local/app_database.dart`, `lib/data/sync/sync_service.dart`, `lib/features/`, `lib/core/router/app_router.dart`, `lib/core/theme/`, `lib/core/utils/student_number.dart`, `lib/main.dart`, and `pubspec.yaml`. Firebase and Android configuration references are `lib/firebase_options.dart`, `firebase.json`, and `android/app/build.gradle.kts`.

