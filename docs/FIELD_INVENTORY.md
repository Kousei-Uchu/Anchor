# Field inventory: what is locked and what is plain

*Patch 35f (D44, D64). Every stored field of every model, and every value the app keeps in the phone's settings, with a verdict, what is true today, and the reason. `scripts/check-field-inventory.mjs` (run by `scripts/check-all.sh`) fails if this list and the code drift apart. Patch 35g does the locking from this list, group by group.*

## How to read it

- **Verdict** is what the field should be once 35g is done. **Locked** means sealed with the data key, so the stored file holds no readable value. **Plain** means it holds nothing that is yours to protect.
- **Today** is what the code does now: `sealed` (a sealed twin exists, from 35b2), `plain`, or `to lock 35gN` (the verdict is locked and the work is queued in that patch).
- **Type** is copied from the code and checked, so a field that changes type has to be looked at again here.

## The rule that decided each verdict

Your 10 Nov 2026 answer to D44 was: lock everything where you put in any data of any kind, dates and numbers included; leave plain only what could never be sensitive; settings values stay plain unless sensitive; where in doubt, lock. Applied field by field:

1. **Locked:** anything you typed, and anything that records what you did, felt, planned or chose: text, names, addresses, dates and times (including when an entry was made or changed), numbers, ratings, strengths, statuses, marks such as done or favourite, and the hours and days you gave for people, sessions and hard times.
2. **Plain:** an id, a link from one item to another by id (a link carries no content once the words are sealed), the order of items on screen, an icon or colour name from a fixed set, a pure on or off switch, one choice from a fixed list that only decides how the app behaves, an app-made flag or time that is not something you entered, and lines shipped with the app.
3. **Reminder times and days** (the hour, minute and weekdays of a reminder) are left plain, because once a reminder is scheduled the phone's own reminder store holds that time unlocked, so sealing it here hides nothing. This is the one place I did not follow "where in doubt, lock", and it is a question for you (D69).
4. **Keys and passcodes** are never in the store or the settings. They are in the Keychain.

Fields that are plain **because they are only a link** are safe only while the words they point to are sealed, which they are. A sealed `title` with a plain `id` tells nobody anything.

## The models

One section per SwiftData model. `Lock in` names the 35g patch that locks what is left in that model, or says none.

## JournalEntry

Lock in: 35g2

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| createdAt | Date | locked | to lock 35g2 | when you made it |
| text | String | locked | sealed | your own words |
| isFavorited | Bool | locked | to lock 35g2 | a mark you put on your own entry |
| linkedContext | EntryOrigin? | locked | to lock 35g2 | how the entry was started, which says what you were doing |
| audioFileName | String? | plain | plain | the name of a voice note file, a generated id; the file itself is sealed by Lock my files (35d) |

## CheckIn

Lock in: 35g1

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| timestamp | Date | locked | to lock 35g1 | when it was recorded |
| physicalExhaustion | Double | locked | to lock 35g1 | how you rated yourself |
| cognitiveBurnout | Double | locked | to lock 35g1 | how you rated yourself |
| mentalLoad | Double | locked | to lock 35g1 | how you rated yourself |
| physicalEnergy | Double | locked | to lock 35g1 | how you rated yourself |
| socialEnergy | Double | locked | to lock 35g1 | how you rated yourself |
| expandedEntryID | UUID? | plain | plain | a link to another item by id, with no content |

## TrustedContact

Lock in: 35g2

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| name | String | locked | sealed | a name you typed |
| phoneNumber | String | locked | sealed | a phone number |
| sortOrder | Int | plain | plain | the order on screen |
| escalationEnabled | Bool | plain | plain | an on or off switch |
| escalationWindowMinutes | Int? | locked | to lock 35g2 | a time you set for a person |
| messageTemplates | [MessageTemplate] | locked | sealed | messages you wrote |
| contactMethod | ContactMethod | plain | plain | one choice from a fixed list that decides which app opens |
| discordUserID | String? | locked | sealed | an id you typed |
| timeZoneIdentifier | String? | locked | to lock 35g2 | where a person is |
| availableFromHour | Int? | locked | to lock 35g2 | the hours a person can be reached |
| availableFromMinute | Int? | locked | to lock 35g2 | the hours a person can be reached |
| availableToHour | Int? | locked | to lock 35g2 | the hours a person can be reached |
| availableToMinute | Int? | locked | to lock 35g2 | the hours a person can be reached |
| helloEnabled | Bool | plain | plain | an on or off switch |
| helloDays | [Int] | plain | plain | a reminder day; the phone's own reminder store holds it unlocked once scheduled, so locking it here hides nothing (D69) |
| helloHour | Int | plain | plain | a reminder time; the phone's own reminder store holds it unlocked once scheduled (D69) |
| helloMinute | Int | plain | plain | a reminder time; the phone's own reminder store holds it unlocked once scheduled (D69) |
| supportDaysEnabled | Bool | plain | plain | an on or off switch |
| supportDaysDayBefore | Bool | plain | plain | an on or off switch |
| companionEnabled | Bool | plain | plain | an on or off switch |
| companionWindowIDs | [UUID] | plain | plain | a link to another item by id, with no content |
| afterSessionEnabled | Bool | plain | plain | an on or off switch |
| afterSessionNextMorning | Bool | plain | plain | an on or off switch |

## GroundingTool

Lock in: 35g3

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| title | String | locked | sealed | a title you typed |
| kind | GroundingToolKind | plain | plain | one choice from a fixed list that decides how the tool opens |
| steps | String? | locked | sealed | steps you wrote |
| deepLink | DeepLinkDestination? | plain | plain | one choice from a fixed list of places in the app |
| sortOrder | Int | plain | plain | the order on screen |
| relevantTimeWindows | [TimeWindowTag] | locked | to lock 35g3 | the times of day you said a tool is for |

## SafetyPlan

Lock in: 35g3

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| lastEditedAt | Date | locked | to lock 35g3 | when you last changed it |
| warningSignsText | String | locked | sealed | your own words |
| copingStrategiesText | String | locked | sealed | your own words |
| reasonsToKeepGoingText | String | locked | sealed | your own words |
| environmentSafetyStepsText | String | locked | sealed | your own words |

## SafetyPlanSection

Lock in: 35g3

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| title | String | locked | sealed | a title you typed |
| text | String | locked | sealed | your own words |
| iconName | String | plain | plain | an icon or colour name from a fixed set |
| tintName | String | plain | plain | an icon or colour name from a fixed set |
| sortOrder | Int | plain | plain | the order on screen |
| isHidden | Bool | plain | plain | an on or off switch |
| role | String | plain | plain | a fixed label that says which built-in section this is, never typed |
| lastEditedAt | Date | locked | to lock 35g3 | when you last changed it |

## BoundarySection

Lock in: 35g3

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| title | String | locked | sealed | a title you typed |
| text | String | locked | sealed | your own words |
| iconName | String | plain | plain | an icon or colour name from a fixed set |
| tintName | String | plain | plain | an icon or colour name from a fixed set |
| sortOrder | Int | plain | plain | the order on screen |
| isHidden | Bool | plain | plain | an on or off switch |
| isShareable | Bool | plain | plain | an on or off switch for sharing, with no content in it |
| lastEditedAt | Date | locked | to lock 35g3 | when you last changed it |

## SleepEntry

Lock in: 35g1

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| nightDate | Date | locked | to lock 35g1 | which night you slept |
| bedTime | Date? | locked | to lock 35g1 | when you went to bed |
| wakeTime | Date? | locked | to lock 35g1 | when you woke |
| minutesAsleep | Int? | locked | to lock 35g1 | how long you slept |
| feel | Int? | locked | to lock 35g1 | how you said the night felt |
| note | String | locked | sealed | your own words |
| sourceRaw | String | plain | plain | typed or from Apple Health, which only decides how the night is treated |
| externalID | String? | plain | plain | an id that Apple Health gave the night, a link and not content |
| createdAt | Date | locked | to lock 35g1 | when you made it |
| lastEditedAt | Date | locked | to lock 35g1 | when you last changed it |

## PersonSection

Lock in: 35g2

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| contactID | UUID | plain | plain | a link to another item by id, with no content |
| title | String | locked | sealed | a title you typed |
| text | String | locked | sealed | your own words |
| iconName | String | plain | plain | an icon or colour name from a fixed set |
| tintName | String | plain | plain | an icon or colour name from a fixed set |
| sortOrder | Int | plain | plain | the order on screen |
| isHidden | Bool | plain | plain | an on or off switch |
| lastEditedAt | Date | locked | to lock 35g2 | when you last changed it |

## PersonalGoal

Lock in: 35g2

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| title | String | locked | sealed | a title you typed |
| why | String | locked | sealed | your own words |
| statusRaw | String | locked | to lock 35g2 | where you say a goal stands |
| notes | [GoalNote] | locked | sealed | your own words |
| sortOrder | Int | plain | plain | the order on screen |
| createdAt | Date | locked | to lock 35g2 | when you made it |
| lastEditedAt | Date | locked | to lock 35g2 | when you last changed it |
| usesSMART | Bool | plain | plain | an on or off switch |
| smartSpecific | String | locked | sealed | your own words |
| smartMeasurable | String | locked | sealed | your own words |
| smartAchievable | String | locked | sealed | your own words |
| smartTimeBound | String | locked | sealed | your own words |

## MessageStarter

Lock in: 35g2

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| text | String | locked | sealed | your own words |
| sortOrder | Int | plain | plain | the order on screen |
| lastEditedAt | Date | locked | to lock 35g2 | when you last changed it |

## TriggerWindow

Lock in: 35g3

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| label | String | locked | sealed | a label you typed |
| daysOfWeek | [Int] | locked | to lock 35g3 | the days you said are hard |
| startHour | Int | locked | to lock 35g3 | the times you said are hard |
| startMinute | Int | locked | to lock 35g3 | the times you said are hard |
| endHour | Int | locked | to lock 35g3 | the times you said are hard |
| endMinute | Int | locked | to lock 35g3 | the times you said are hard |
| isActive | Bool | plain | plain | an on or off switch |

## AppointmentSeries

Lock in: 35g3

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| clinicianLabel | String | locked | sealed | a name you typed |
| typicalDayOfWeek | Int? | locked | to lock 35g3 | when you usually see someone |
| typicalHour | Int? | locked | to lock 35g3 | when you usually see someone |
| typicalMinute | Int? | locked | to lock 35g3 | when you usually see someone |
| typicalCadenceDays | Int | locked | to lock 35g3 | how often you see someone |
| role | String | locked | sealed | a word you typed |
| exportLabel | String | locked | sealed | a name you typed |
| notes | String | locked | sealed | your own words |
| sortOrder | Int | plain | plain | the order on screen |
| occurrences | [AppointmentOccurrence] | plain | plain | the link from a series to its sessions |

## AppointmentOccurrence

Lock in: 35g3

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| scheduledDate | Date | locked | to lock 35g3 | when the session is |
| wasMoved | Bool | locked | to lock 35g3 | records what you did with a session |
| prepNoteEntryID | UUID? | plain | plain | a link to another item by id, with no content |
| postSessionNoteEntryID | UUID? | plain | plain | a link to another item by id, with no content |
| prepChecklist | [QuickListItem] | locked | sealed | a checklist you wrote |

## BridgeDraftItem

Lock in: 35g2

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| createdAt | Date | locked | to lock 35g2 | when you made it |
| text | String | locked | sealed | your own words |
| isResolved | Bool | locked | to lock 35g2 | records that you raised something |
| isQuestion | Bool | locked | to lock 35g2 | which kind of item you wrote |
| answer | String | locked | sealed | your own words |
| providerID | UUID? | plain | plain | a link to another item by id, with no content |
| sourceEntryID | UUID? | plain | plain | a link to another item by id, with no content |

## FeedbackLoopDiagram

Lock in: 35g3

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| title | String | locked | sealed | a title you typed |
| lastEditedAt | Date | locked | to lock 35g3 | when you last changed it |
| graphJSON | Data | locked | sealed | the diagram you drew |

## ThreadMessage

Lock in: 35g2

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| timestamp | Date | locked | to lock 35g2 | when it was recorded |
| text | String | locked | sealed | your own words |
| audioFileName | String? | plain | plain | the name of a voice note file, a generated id; the file itself is sealed by Lock my files (35d) |
| withContactID | UUID? | plain | plain | a link to another item by id, with no content |
| followUpAt | Date? | locked | to lock 35g2 | when you asked to be reminded |

## SupportCalendarEntry

Lock in: 35g2

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| date | Date | locked | to lock 35g2 | the day it is about |
| note | String | locked | sealed | your own words |
| visibleToContactIDs | [UUID] | plain | plain | a link to another item by id, with no content |

## FutureNote

Lock in: 35g2

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| writtenAt | Date | locked | to lock 35g2 | when you wrote it |
| unlockDate | Date | locked | to lock 35g2 | when you chose for it to open |
| text | String | locked | sealed | your own words |
| isUnlocked | Bool | locked | to lock 35g2 | follows the date you chose, so it would give that date away |
| openWhen | String | locked | sealed | your own words |

## UnsentDraft

Lock in: 35g2

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| createdAt | Date | locked | to lock 35g2 | when you made it |
| recipientLabel | String | locked | sealed | a name you typed |
| text | String | locked | sealed | your own words |
| wasSent | Bool | locked | to lock 35g2 | records what you did with a draft |

## DecisionPresetCategory

Lock in: none

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| name | String | locked | sealed | a name you typed |
| sortOrder | Int | plain | plain | the order on screen |
| choices | [DecisionPresetChoice] | plain | plain | the link from a category to its choices |

## DecisionPresetChoice

Lock in: none

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| name | String | locked | sealed | a name you typed |
| steps | String | locked | sealed | steps you wrote |
| sortOrder | Int | plain | plain | the order on screen |
| category | DecisionPresetCategory? | plain | plain | the link from a choice to its category |

## DeEscalationScript

Lock in: none

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| text | String | locked | sealed | your own words |
| sortOrder | Int | plain | plain | the order on screen |

## Affirmation

Lock in: none

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| text | String | locked | sealed | your own words |
| sortOrder | Int | plain | plain | the order on screen |

## NextHourItem

Lock in: 35g3

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| text | String | locked | sealed | your own words |
| isDone | Bool | locked | to lock 35g3 | records what you did |
| createdAt | Date | locked | to lock 35g3 | when you made it |
| reminderIdentifier | String? | plain | plain | an id that the phone's reminders gave, a link and not content |

## TaskItem

Lock in: 35g3

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| title | String | locked | sealed | a title you typed |
| notes | String | locked | sealed | your own words |
| isDone | Bool | locked | to lock 35g3 | records what you did |
| completedAt | Date? | locked | to lock 35g3 | when you finished it |
| createdAt | Date | locked | to lock 35g3 | when you made it |
| sortOrder | Int | plain | plain | the order on screen |
| reminderIdentifier | String? | plain | plain | an id that the phone's reminders gave, a link and not content |
| dueKind | TaskDueKind | locked | to lock 35g3 | goes with the day you gave |
| dueDate | Date? | locked | to lock 35g3 | the day you gave it |
| parentID | UUID? | plain | plain | a link to another item by id, with no content |
| subtasksCollapsed | Bool | plain | plain | whether a list of steps is folded on screen |
| blockedByIDs | [UUID] | plain | plain | a link to another item by id, with no content |
| status | TaskStatus | locked | to lock 35g3 | where you say a task stands |
| energy | TaskEnergy | locked | to lock 35g3 | how much energy you say it needs |
| firstStep | String | locked | sealed | your own words |
| focusSessions | Int | locked | to lock 35g3 | how much you worked on it |
| focusMinutes | Int | locked | to lock 35g3 | how much you worked on it |
| estimateMinutes | Int | locked | to lock 35g3 | a time you gave it |
| sourceEntryID | UUID? | plain | plain | a link to another item by id, with no content |

## QuickList

Lock in: 35g3

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| title | String | locked | sealed | a title you typed |
| createdAt | Date | locked | to lock 35g3 | when you made it |
| items | [QuickListItem] | locked | sealed | items you wrote |
| archivedAt | Date? | locked | to lock 35g3 | when you archived it |

## Routine

Lock in: 35g3

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| name | String | locked | sealed | a name you typed |
| createdAt | Date | locked | to lock 35g3 | when you made it |
| steps | [RoutineStep] | locked | sealed | steps you wrote |
| reminderEnabled | Bool | plain | plain | an on or off switch |
| reminderDays | [Int] | plain | plain | a reminder day; the phone's own reminder store holds it unlocked once scheduled (D69) |
| reminderHour | Int | plain | plain | a reminder time; the phone's own reminder store holds it unlocked once scheduled (D69) |
| reminderMinute | Int | plain | plain | a reminder time; the phone's own reminder store holds it unlocked once scheduled (D69) |

## ItemList

Lock in: 35g3

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| name | String | locked | sealed | a name you typed |
| createdAt | Date | locked | to lock 35g3 | when you made it |
| variables | [ListVariable] | locked | sealed | words you typed |
| items | [ListItem] | locked | sealed | items you wrote |

## MascotLine

Lock in: none

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| trigger | MascotTrigger | plain | plain | shipped content, one choice from a fixed list |
| mood | MascotMood | plain | plain | shipped content, one choice from a fixed list |
| text | String | plain | plain | a line shipped with the app and never typed by the person; the check fails if a user-authored line is ever written |
| isUserAuthored | Bool | plain | plain | always false today, and the check fails if anything sets it to true |

## RecoveryCounter

Lock in: 35g1

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| name | String | locked | sealed | a name you typed |
| discreetLabel | String | locked | sealed | a label you typed |
| showNameOutsideApp | Bool | plain | plain | an on or off switch |
| mode | DayCountMode | locked | to lock 35g1 | what kind of count it is |
| runsData | Data | locked | sealed | the start and end dates of the counter, kept as data |
| savingsAmount | Double | locked | to lock 35g1 | a number you entered |
| savingsPeriod | SavingsPeriod | locked | to lock 35g1 | goes with the amount you entered |
| currencyCode | String | locked | to lock 35g1 | goes with the amount you entered |
| acknowledgedMilestones | [Int] | locked | to lock 35g1 | which milestones you have reached |
| sortOrder | Int | plain | plain | the order on screen |
| createdAt | Date | locked | to lock 35g1 | when you made it |
| isArchived | Bool | plain | plain | an on or off switch for showing it |
| priorTimesPerDay | Int | locked | to lock 35g1 | a number you entered |

## RecoveryMotivation

Lock in: 35g1

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| kind | MotivationKind | locked | to lock 35g1 | which kind of reason you wrote |
| text | String | locked | sealed | your own words |
| sortOrder | Int | plain | plain | the order on screen |
| createdAt | Date | locked | to lock 35g1 | when you made it |

## RecoveryDayEntry

Lock in: 35g1

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| counterID | UUID | plain | plain | a link to another item by id, with no content |
| day | Date | locked | to lock 35g1 | the day it is about |
| pledgedAt | Date? | locked | to lock 35g1 | when you made the pledge |
| reviewedAt | Date? | locked | to lock 35g1 | when you did the review |
| helped | String | locked | sealed | your own words |
| hard | String | locked | sealed | your own words |
| tomorrow | String | locked | sealed | your own words |
| slipTimes | Int | locked | to lock 35g1 | a number you entered |

## RecoveryUrge

Lock in: 35g1

| Field | Type | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| id | UUID | plain | plain | its own id |
| counterID | UUID | plain | plain | a link to another item by id, with no content |
| date | Date | locked | to lock 35g1 | the day it is about |
| strength | UrgeStrength | locked | to lock 35g1 | how strong you said an urge was |
| note | String | locked | sealed | your own words |

## Settings and other stored values

Every key the app keeps in the phone's settings (UserDefaults and `@AppStorage`). `scripts/check-field-inventory.mjs` fails if the code stores a key that is not in this table, or this table lists one the code no longer stores. A key with `<tab>` or `<widget>` stands for one key for each tab or widget.

| Key | Holds | Verdict | Today | Reason |
| --- | --- | --- | --- | --- |
| sleepFeelWords | the three words you chose for how a night felt | locked | to lock 35g4 | words you typed |
| aiOllamaAddress | the address of your own computer | locked | to lock 35g4 | an address you typed |
| aiOllamaModel | a model name | locked | to lock 35g4 | a name you typed |
| aiOllamaConfirmedAway | the away address you confirmed | locked | to lock 35g4 | an address you typed |
| aiOtherAddress | the address of a service you added | locked | to lock 35g4 | an address you typed; its key is in the Keychain and never here |
| aiOtherModel | a model name | locked | to lock 35g4 | a name you typed |
| anchor.dayPlan | the tasks you picked for today, their order and the time you said you have | locked | to lock 35g4 | what you planned to do, and a time you gave |
| anchor.escalationSkipped | which escalation reminders you answered, by id and day | locked | to lock 35g4 | records what you did on a day; whatever reads it must open the key first |
| anchor.sleep.health.written | for each night saved to Apple Health, its id and when it was last changed | locked | to lock 35g4 | the last-changed time of a night is a date of yours, kept as a number |
| aiToolsEnabled | the one switch for all AI tools | plain | plain | an on or off switch |
| dictationEnabled | dictation in the Journal | plain | plain | an on or off switch |
| dictationKeepsVoiceNote | keep a voice note while dictating | plain | plain | an on or off switch |
| dictationLabelsSpeakers | label who is speaking while dictating | plain | plain | an on or off switch |
| anchor.appLockEnabled | the app lock | plain | plain | an on or off switch |
| anchor.showcaseOn | Showcase mode | plain | plain | an on or off switch |
| anchor.dailyCheckIn.enabled | the daily check-in reminder | plain | plain | an on or off switch |
| anchor.sleep.reminder.enabled | the sleep morning reminder | plain | plain | an on or off switch |
| anchor.sleep.journal | sleep in the Journal | plain | plain | an on or off switch |
| anchor.sleep.checkIn | the sleep question in the check-in | plain | plain | an on or off switch |
| anchor.sleep.nowCard | the Last night card on Now | plain | plain | an on or off switch |
| anchor.sleep.health.read | reading sleep from Apple Health | plain | plain | an on or off switch |
| anchor.sleep.health.write | saving typed nights to Apple Health | plain | plain | an on or off switch |
| reminders.appointment.dayBefore | the day-before session reminder | plain | plain | an on or off switch |
| reminders.appointment.sameDay | the same-day session reminder | plain | plain | an on or off switch |
| recovery.pledgeReminder.enabled | the pledge reminder | plain | plain | an on or off switch |
| recovery.reviewReminder.enabled | the review reminder | plain | plain | an on or off switch |
| recovery.milestoneReminders.enabled | milestone reminders | plain | plain | an on or off switch |
| recovery.showLongest | show the longest run | plain | plain | an on or off switch |
| recovery.triggerSuggestion.dismissed | whether you hid the trigger-window suggestion | plain | plain | an on or off switch |
| anchor.focus.alertsEnabled | focus alerts | plain | plain | an on or off switch |
| anchor.focus.lockScreen | the focus timer on the lock screen | plain | plain | an on or off switch |
| anchor.focus.breaksOn | breaks in the focus timer | plain | plain | an on or off switch |
| anchor.focus.autoStart | start the next phase by itself | plain | plain | an on or off switch |
| anchor.focus.haptic | a tap when a phase ends | plain | plain | an on or off switch |
| anchor.focus.alertSound | a sound when a phase ends | plain | plain | an on or off switch |
| anchor.dataViewer.blur | blur in the data viewer | plain | plain | an on or off switch |
| anchor.hasSeenTour | whether the tour has been shown | plain | plain | an on or off switch |
| anchor.dailyCheckIn.hour | the check-in reminder time | plain | plain | a reminder time from a picker; the phone's own reminder store holds it unlocked once scheduled (D69) |
| anchor.dailyCheckIn.minute | the check-in reminder time | plain | plain | a reminder time from a picker; the phone's own reminder store holds it unlocked once scheduled (D69) |
| anchor.sleep.reminder.hour | the sleep reminder time | plain | plain | a reminder time from a picker; the phone's own reminder store holds it unlocked once scheduled (D69) |
| anchor.sleep.reminder.minute | the sleep reminder time | plain | plain | a reminder time from a picker; the phone's own reminder store holds it unlocked once scheduled (D69) |
| reminders.appointment.eveningHour | the evening-before reminder time | plain | plain | a reminder time from a picker; the phone's own reminder store holds it unlocked once scheduled (D69) |
| reminders.appointment.eveningMinute | the evening-before reminder time | plain | plain | a reminder time from a picker; the phone's own reminder store holds it unlocked once scheduled (D69) |
| recovery.pledgeReminder.hour | the pledge reminder time | plain | plain | a reminder time from a picker; the phone's own reminder store holds it unlocked once scheduled (D69) |
| recovery.pledgeReminder.minute | the pledge reminder time | plain | plain | a reminder time from a picker; the phone's own reminder store holds it unlocked once scheduled (D69) |
| recovery.reviewReminder.hour | the review reminder time | plain | plain | a reminder time from a picker; the phone's own reminder store holds it unlocked once scheduled (D69) |
| recovery.reviewReminder.minute | the review reminder time | plain | plain | a reminder time from a picker; the phone's own reminder store holds it unlocked once scheduled (D69) |
| anchor.focus.focusMinutes | minutes in a focus round | plain | plain | a timer length from a picker, about how the timer runs and not about you |
| anchor.focus.shortBreakMinutes | minutes in a short break | plain | plain | a timer length from a picker, about how the timer runs and not about you |
| anchor.focus.longBreakMinutes | minutes in a long break | plain | plain | a timer length from a picker, about how the timer runs and not about you |
| anchor.focus.roundsBeforeLongBreak | rounds before a long break | plain | plain | a timer length from a picker, about how the timer runs and not about you |
| aiProviderChoice | which place AI runs: this phone, your computer or Other | plain | plain | one choice from a fixed list |
| aiAskSkips | pairs of a tool and a place you said not to be asked about again | plain | plain | pairs of fixed names, no typed words |
| anchor.journal.layout | days or another Journal layout | plain | plain | one choice from a fixed list |
| tabLayoutStyle | widgets or icons on Plan, Bridge and Thread | plain | plain | one choice from a fixed list |
| widgetOrder.<tab> | the order of widgets on a tab | plain | plain | a list of fixed widget names |
| widgetHidden.<tab> | the widgets hidden on a tab | plain | plain | a list of fixed widget names |
| widgetFull.<tab> | the widgets made full width | plain | plain | a list of fixed widget names |
| widgetSeeded.<tab>.<widget> | a flag that a hidden-by-default widget was hidden once | plain | plain | an on or off flag |
| anchor.crisisRegion | which country's crisis numbers to show, or auto | plain | plain | one choice from a fixed list of countries (D69) |
| anchor.safetyPlanSectionsMade | a flag that the Safety plan sections were made once | plain | plain | an on or off flag set by a migration |
| anchor.tasksMigratedFromNextHour | a flag that Next hour items were moved to Tasks once | plain | plain | an on or off flag set by a migration |
| anchor.sleep.health.lastSync | when Anchor last read Apple Health | plain | plain | a time the app did something, not something you entered |
| anchor.sleep.health.writeSince | the day from which typed nights are saved to Apple Health | plain | plain | a cut-off the app sets itself, thirty days back at most |
| anchor.sleep.nowDismissedDay | the day the Last night card was hidden | plain | plain | screen state about one card |
| anchor.showcasePasscodeFails | how many wrong Showcase passcodes in a row | plain | plain | a counter for the wait after wrong tries; the passcode is in the Keychain |
| anchor.showcasePasscodeWaitUntil | when the Showcase passcode may be tried again | plain | plain | a time the app sets for itself after wrong tries |
| lockMyData.state | how far Lock my data or Lock my files has got | plain | plain | the app's own progress word |
| lockMyFiles.state | how far Lock my data or Lock my files has got | plain | plain | the app's own progress word |
| lockMyData.requested | a job waiting for the next start | plain | plain | an on or off style flag for a job |
| lockMyFiles.requested | a job waiting for the next start | plain | plain | an on or off style flag for a job |
| lockMyData.scrubWaiting | a job waiting for the next start | plain | plain | an on or off style flag for a job |
| safetyCopy.pending | a job waiting for the next start | plain | plain | an on or off style flag for a job |
| lockMyData.lockedAt | when the lock run finished | plain | plain | a time the app did something, not something you entered |
| lockMyFiles.lockedAt | when the lock run finished | plain | plain | a time the app did something, not something you entered |
| lockMyData.items | how many items the last lock run checked | plain | plain | a count the app made of its own work |
| lockMyFiles.items | how many items the last lock run checked | plain | plain | a count the app made of its own work |
| lockMyData.lastResult | a plain line saying how the last run went | plain | plain | the app's own message, with no content of yours in it |
| lockMyFiles.lastResult | a plain line saying how the last run went | plain | plain | the app's own message, with no content of yours in it |
| safetyCopy.lastResult | a plain line saying how the last run went | plain | plain | the app's own message, with no content of yours in it |

## Other places that hold your data

Not checked by the script, listed so the picture is whole.

- **Keychain:** the data key, the key for an Other AI provider, and the Showcase passcode. Never in the store or the settings.
- **Widget summaries** (app group settings, `AnchorWidgetSnapshot.sealed` and `AnchorCounterWidgetItems.sealed`): sealed with their own key since 35a, with no plain copy kept.
- **Voice notes and Journal photos:** files, sealed by Lock my files (35d). Their names are generated ids.
- **Safety copy and encrypted backups:** exact copies, kept on the phone or made by you. The safety copy is made before anything is locked and holds the data as it was.
- **Sleep samples in Apple Health:** Apple's own store, saved only if you switch it on, and removable from the Sleep screen.

## What 35g has to watch

- **Sorting and filtering.** SwiftData cannot sort or filter on a sealed value. Run `node scripts/check-field-inventory.mjs --uses` to list every place that sorts or filters on a field still to lock; As of 35f there are 37 such places where the database sorts or filters (D64 guessed about fifteen), and 52 more that sort or filter in memory, which keep working because reading a locked field already opens it. 35g moves each of the 37 to an in-memory sort after the items are opened. The existing check (`check-locked-fields.mjs`, rule 4) then stops any new sort on a sealed field.
- **Switches that record what you did** (done, favourite, resolved, sent, moved) are locked in 35g, so a screen that filters on `isDone` or `isResolved` opens the items first.
- **Settings that something reads while the phone is locked** (`anchor.escalationSkipped`, and the day plan) need the key to be available, or to fail closed and show nothing, never to show a sealed string. 35g4 decides this key by key and says so.
- **Each group ships alone,** with a safety copy and the way back first, and is checked on your phone before the next group starts.
