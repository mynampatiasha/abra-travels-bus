# Design system

The visual standard for every Abra Travels interface (customer app, management app, and the apps still to come). Code: `packages/shared_theme` (tokens and theme) and `packages/shared_ui` (components). Screens take colours, spacing, radii, shadows, gradients and motion from there and never define their own.

**A feature is complete only with its interface**: the flow, the designed screen, loading, empty and error states, validation, feedback, responsive layout and accessibility are delivered together with the logic and the API integration.

## 1. Colour

| Token (`AbraColors`) | Value | Use |
|---|---|---|
| `navy` | `#071E3D` | Navigation, top bars, headings and body text |
| `navySecondary` | `#0B3B6E` | Secondary navy surfaces, start of the action gradient |
| `blue` | `#1677C8` | Primary actions, selection, links |
| `brightBlue` | `#0878C9` | Gradient, emphasis |
| `skyBlue` | `#20B9F3` | Accent on navy surfaces only (white text does not reach 4.5:1 on it) |
| `lightBlue` | `#E8F6FD` | Selected and informational backgrounds |
| `lightGray` | `#F3F5F7` | Page background, table headings |
| `white` | `#FFFFFF` | Content surfaces |

Green (`teal`), orange and red are used only for what they mean, through `AbraStatusColors` (success, warning, info, danger, neutral). Orange is not an action colour.

Gradients (`AbraGradients`): `brand` is the approved 135° gradient (navy → secondary navy → bright blue → sky blue), for brand surfaces; `brandDeep` stops at bright blue, for surfaces that carry white text across their whole width; `action` fills the main call to action. Text on a gradient is white.

## 2. Components (`shared_ui`)

| Component | Purpose |
|---|---|
| `AbraButton` | `callToAction` (brand gradient, one per screen), `primary`, `secondary`, `text`; loading and disabled states |
| `AbraCard`, `AbraStatusBadge`, `AbraConfirmDialog` | Surfaces, status pills, confirmations |
| `AbraStateView`, `AbraFailureView`, `AbraLoadingView` | Empty, error, no connection, no access, session ended, loading |
| `AbraSkeleton`, `AbraSkeletonGroup` | The shape of content while it loads; announced once as "Loading" |
| `AbraEntrance`, `AbraMotion` | Fade-and-rise entrance, staggered in lists; motion rules |
| `AbraBrandSurface`, `AbraBrandMark` | Brand gradient with the route motif; the product mark |
| `AbraJourneyLine` | The track between departure and arrival |

A component that more than one screen needs is added here, not built in a screen.

## 3. Motion

Short and purposeful: `AbraDurations` (150, 250, 400 ms), entrances with `AbraEntrance`, state changes with a cross-fade. Every animated component checks `AbraMotion.isReduced` and shows its final state at once when the device asks for reduced motion.

## 4. The two apps

- **Customer app**: visual and travel-oriented. Brand gradient hero with the search card, journey cards with the route line, bottom navigation on phones and a navy rail on wider screens.
- **Management app**: the same brand, denser. Navy side navigation with a blue active item (a drawer below 1024 px), white top bar naming the section, one white data surface per list: filters and actions, table, pagination.

## 5. Tables in the management app

Row actions are pinned at the trailing edge and are always on screen. When the data columns do not fit they scroll sideways under the pinned column, with a visible scrollbar and a shadow on the pinned column. Below 640 px each record is a block with labelled values and its actions.

## 6. States

Every data screen has: loading (skeleton), empty (what is missing and what to do), no results for the filters (with "Clear filters"), failure by kind (no connection, timeout, server, no access, session ended) with a retry where retrying can help. Raw server messages are never shown.

## 7. Checked widths

Customer: 320, 390, 1366. Management: 390, 768, 1366, 1920. Tests keep row actions inside the viewport at 1024 and 1366 and cover the phone layout.
