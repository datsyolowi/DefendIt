# DefendIt repository verification

Reviewed against `C:/Users/Lorie/Downloads/Contents - Copy.docx` on 21 October 2026. The corrected guide was derived from that attachment, with implementation evidence used to resolve discrepancies. Application source and the downloaded original were not edited.

## Scope and evidence boundaries

The review covers all 62 files under `lib/`, dependency declarations and lockfile, Firebase configuration, Android manifests and Gradle settings, the six platform folders, native test scaffolds, repository documentation, and existing release metadata. Generated caches, Git objects, and third-party dependencies are not application source. Existing release outputs were inspected as historical artifacts, not rebuilt or assumed to match today's modified working tree.

No connected Firebase account, deployed rules, production documents, adviser-code inventory, device session, or signing keystore was queried. Comments claiming security-rule enforcement are not evidence that those rules are deployed.

## Verification actually performed

| Check | Result |
|---|---|
| `flutter analyze --no-pub` | Exit 1; 11 informational findings; no errors or warnings reported. Findings concern underscore parameters, deprecated dropdown `value`, initializing formals, and interpolation braces. |
| `flutter test --no-pub` | Exit 1: `Test directory "test" not found.` |
| Native runner tests | iOS and macOS contain empty `testExample` scaffolds, not DefendIt workflow tests. |
| SQLite schema | Version 4; six tables and four indexes verified. Automated field comparison matched all five mirrored model payloads to SQL columns, adding the local id column; see Schema_Verification.json. |
| Existing Android release | `app-release.apk`, version 1.0.0+1, dated 12 October 2026; not a fresh build of this source. |
| Android platform baseline | Installed Flutter Gradle default and existing packaged release manifest specify minSdk 24, Android 7.0. |
| Release internet permission | Existing merged/packaged release includes INTERNET contributed by Google sign-in/Firebase dependencies; absence from the main source manifest does not prove the APK lacks it. |
| Cloud authorization and end-to-end sync | Not executed; local code inspection cannot establish deployed behavior. |

## Discrepancies corrected in the guide

| Area | Correction | Repository evidence |
|---|---|---|
| Heading and persona text | Removed the accidentally appended “Roles and permissions” and stray member “B”; explained leader versus authenticated student role. | Attachment; `lib/data/models/app_user.dart`, `group.dart`. |
| Palette | Replaced deep-indigo claims with actual teal/sage/amber hex values; legacy names are distinguished from hues. Conceptual figures now use teal. | `lib/core/theme/app_colors.dart`. |
| Typography | Inter is used for app headings and body, not Source Serif 4. Century Gothic remains the document font. | `lib/core/theme/app_text_styles.dart`, `app_theme.dart`. |
| App identity | Login displays DefendIt; app title/constants retain ThesisTrack, and Android launcher label remains thesis_track. | `lib/features/auth/login_screen.dart`, `lib/app.dart`, `lib/core/constants/strings.dart`, Android main manifest. |
| Minimum Android version | Removed Android 6.0 as an implementation baseline; current SDK default is API 24. | Android Gradle configuration, installed FlutterExtension, existing packaged release manifest. |
| Platforms | Android/web Firebase options exist; other native platforms explicitly throw UnsupportedError. Web still lacks SQLite adaptation and a web-specific Google sign-in flow. | `lib/firebase_options.dart`, `auth_repository.dart`, `app_database.dart`, `pubspec.yaml`. |
| Dependencies | Recorded actual Dart/Flutter constraints and main package versions. | `pubspec.yaml`, `pubspec.lock`. |
| Group roster | Official roster names and account membership differ; joining updates memberUids/memberNames, not roster. Two-to-five applies to the initial named roster. | `group_repository.dart`, `group.dart`. |
| Concurrent membership | One-group checks and join-code generation are pre-checks, not a single globally serializable membership or uniqueness transaction. | `group_repository.dart`. |
| Adviser acceptance | Transaction checks the group and shared adviserGroupCount, then updates both. | `group_repository.dart: acceptGroup`. |
| Slot publication | Overlap rejection is a query before creation, not an atomic exclusion constraint. Booking one existing slot is transactional. | `slot_repository.dart: createSlot`, `bookSlot`. |
| Title workflow | Permitted edits, delete guard, required feedback, and review reset are explicit. Approval does not update groups.thesisTitle or approve a milestone. | `title_repository.dart`, `title_idea.dart`. |
| Milestones | Listed all six defaults, exact transitions, nonempty-completed-task submission gate, task locks, first-task start, and progress formula. Positions do not enforce prerequisite approvals. | `milestone.dart`, `milestone_repository.dart`, milestone board/detail screens. |
| Authentication | Explained exact student regex, same-UID adviser-code reuse, no fixed 15-code requirement, and partial success when joining after registration fails. | `student_number.dart`, `auth_repository.dart`, `auth_provider.dart`. |
| Sessions and routing | Documented four auth states/routes, per-UID database opening, and retained files on sign-out. | `app_router.dart`, `main_shell.dart`, `sync_service.dart`, `app_database.dart`. |
| Firestore schema | Restored title `createdByName`; removed `label` as an assumed required adviser-code field; differentiated document IDs from payload fields and timestamps from integer dates. | Models and authentication/group repository writes. |
| SQLite types | Clarified mirrored text IDs versus integer outbox sequence, boolean and JSON conversions, schema version, and lack of foreign keys/cascades. | `app_database.dart`, model `toRow` methods. |
| Security | Recast security policies as required and unverified where no deployed rules evidence exists; noted consultation repository lacks actor guards. | No rules file; `firebase.json` only configures Flutter; `consultation_repository.dart`. |
| Sync | Added actual queue fields, 12-second timeout, ordered replay, retry triggers, listener scope, pending-write suppression, timestamp limitations, and hidden listener errors. | `sync_service.dart`, repositories, `sync_chip.dart`. |
| Testing/delivery claims | Removed implied proof of a current tested release or supplied Flutter suite/separately named Test Cases Document. | Repository inventory; analyzer/test results; historical artifact timestamp. |

## Implementation gaps that remain

These are code/configuration findings, not problems that changing prose can repair. No app code was changed during this documentation audit.

1. **Backend authorization cannot be verified.** No `firestore.rules`, emulator tests, or rules deployment configuration is supplied. Consultation writes have no actor parameter; UI role restrictions alone do not secure direct backend access. Role and student-number immutability also depend on deployed rules.
2. **Membership constraints are not atomic.** `joinByCode` reads membership, then updates the target group separately. Concurrent joins or a join/create race can bypass a one-group pre-check. Joining does not check the official roster or cap signed-in accounts at five. Code generation queries for collisions before writing, without an atomic unique-code registry.
3. **Published slots can overlap under concurrency.** `createSlot` queries existing slots and later creates a document. Two concurrent publishers may both pass. `bookSlot` does protect competing reservations of the same document; these are different guarantees.
4. **Sync error handling is limited.** A permanently rejected first outbox operation blocks later operations for that flush. There is no dead-letter queue or timed backoff worker. Listener/apply errors are suppressed, and the chip does not display `lastError`. A pending write can remain labeled Syncing after an unsuccessful attempt.
5. **Account changes during in-flight synchronization need a race-condition fix or proof.** `flush` awaits a remote push, then calls the shared database's `removeOp(seq)`. `stop/start` changes `_user` and reopens the same AppDatabase object without awaiting the old flush. If the UID changes while a push is pending, a completion can operate on the newly selected database. This is a static code risk, not a reproduced incident. Separate files alone do not prove safe concurrent switching.
6. **Query membership changes do not purge all old local rows.** Group subscriptions are canceled and replaced, but `_onGroups` does not explicitly purge records from groups no longer returned. The app has no leave/edit-group workflow, so this mainly matters for externally changed memberships and should be integration-tested.
7. **Release branding and signing remain provisional.** Main manifest and platform metadata still carry thesis_track/ThesisTrack branding; release signing uses the debug configuration and the package ID is com.example.thesis_track. The INTERNET permission is currently dependency-contributed in existing release output; verify each fresh build's merged manifest.
8. **Runtime verification is incomplete.** No Flutter test directory, rule tests, current-source build run, or device/Firebase execution was completed. Existing APKs must not be used as evidence that recently modified Dart source has been tested.
9. **Repository handover documentation remains generic.** README and pubspec description still say “A new Flutter project.” The empty `lib/data/remote/firestore_service.dart` does not implement a shared remote service; active repositories and SyncService access Firebase directly.

## Schema verification notes

The corrected Figure 6.1 groups exact payload fields by type. Operational `ms` values are integer milliseconds; `timestamp` means a Firestore timestamp. Optional registry provisioning metadata may exist remotely but is not required or read by this code. The outbox schema is local only.

Explicit local indexes: `idx_items_consultation` on action_items(consultationId), `idx_titles_group` on title_ideas(groupId), `idx_milestones_group` on milestones(groupId), and `idx_tasks_milestone` on milestone_tasks(milestoneId). Upgrades introduce title_ideas at version 2, milestones at 3, and milestone_tasks at 4.

No automatic cascade is implemented for group, milestone, or consultation deletion. No group edit/delete, custom milestone create/delete, or action-item title-edit UI is supplied. CRUD is available across supported entities and actions; it is not unrestricted CRUD for every collection.
