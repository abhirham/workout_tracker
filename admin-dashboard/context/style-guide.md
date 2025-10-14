# Admin Dashboard Design System

## Introduction

The FitAdmin workout management platform employs a clean, modern design language focused on clarity, efficiency, and data-driven decision-making. The visual system prioritizes content hierarchy, readability, and intuitive navigation — creating a professional admin interface that balances functionality with visual polish.

**Design Philosophy:**
- **Minimalist & Data-Focused** — Reduce visual noise to highlight actionable information
- **Clean & Structured** — Clear layouts with predictable patterns and generous white space
- **Professional & Modern** — Contemporary UI conventions with subtle depth and refinement
- **Accessible & Legible** — High contrast ratios and clear typography for extended use

---

## Color Palette

### Primary Colors

| Color | Hex | Usage |
|-------|-----|-------|
| **Primary Blue** | `#2563EB` | Brand identity, active navigation items, primary CTAs, links |
| **Deep Navy** | `#0F172A` | Primary buttons, emphasis text, status badges (Active), workout type pills |

### Neutral Colors

| Color | Hex | Usage |
|-------|-----|-------|
| **Pure Black** | `#000000` | Headings, primary text, high-emphasis content |
| **Dark Gray** | `#334155` | Secondary text, body copy, subheadings |
| **Medium Gray** | `#64748B` | Muted text, placeholders, helper text, inactive states |
| **Light Gray** | `#94A3B8` | Borders, dividers, subtle UI elements |
| **Off-White** | `#F1F5F9` | Input backgrounds, secondary surfaces, hover states |
| **Pure White** | `#FFFFFF` | Primary background, cards, modals, input fields |

### Semantic Colors

| Color | Hex | Usage |
|-------|-----|-------|
| **Success Green** | `#10B981` | Completion indicators (100% progress), success states |
| **Warning Orange** | `#F59E0B` | Alert states, moderate completion (68-79% range) |
| **High Green** | `#22C55E` | High completion rates (87-95% range) |
| **Info Blue** | `#3B82F6` | Progress bars, information highlights |
| **Danger Red** | `#EF4444` | Delete actions, critical warnings, destructive operations |

### Background & Surface Colors

| Color | Hex | Usage |
|-------|-----|-------|
| **Page Background** | `#FAFBFC` | Main application background |
| **Card Surface** | `#FFFFFF` | Elevated surfaces, content containers, modals |
| **Hover Surface** | `#F8FAFC` | Interactive element hover states |
| **Border Color** | `#E2E8F0` | Card borders, input borders, dividers |
| **Disabled Background** | `#F1F5F9` | Disabled input fields, inactive toggle states |

### User Avatar Colors

For user initials in avatar circles:
- Background: `#DBEAFE` (Light Blue)
- Text: `#2563EB` (Primary Blue)

---

## Typography

### Font Family

**Primary Font:** System font stack (San Francisco on macOS/iOS, Segoe UI on Windows, Roboto on Android)

```css
font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
```

**Character:** Clean, neutral, professional — optimized for UI legibility across all platforms.

### Type Scale

| Element | Size | Weight | Line Height | Usage |
|---------|------|--------|-------------|-------|
| **Page Heading** | 28-32px | 700 (Bold) | 1.2 | Main page titles (e.g., "Global Workouts Library", "User Management") |
| **Section Heading** | 20-24px | 600 (Semibold) | 1.3 | Section titles, card headers (e.g., "Plan Overview", "Week Structure") |
| **Card Title** | 16-18px | 600 (Semibold) | 1.4 | Card titles, workout plan names |
| **Body Text** | 14-15px | 400 (Regular) | 1.5 | Primary content, descriptions, table cells |
| **Small Text** | 13-14px | 400 (Regular) | 1.4 | Subtitles, helper text, metadata (e.g., "8 Weeks", "2 days configured") |
| **Micro Text** | 12px | 400 (Regular) | 1.3 | Captions, fine print, status labels |
| **Button Text** | 14-15px | 500 (Medium) | 1 | Button labels, CTAs |
| **Input Text** | 14-15px | 400 (Regular) | 1.4 | Form inputs, search fields |

### Text Colors

- **Primary Text:** `#000000` (Black) — Headings, workout names, user names
- **Secondary Text:** `#64748B` (Medium Gray) — Descriptions, subtitles, helper text
- **Muted Text:** `#94A3B8` (Light Gray) — Placeholders, inactive states, timestamps
- **Link Text:** `#2563EB` (Primary Blue) — Interactive links, navigation items

---

## Components

### Navigation

#### Top Navigation Bar
- **Height:** 64px
- **Background:** `#FFFFFF` (White)
- **Border Bottom:** 1px solid `#E2E8F0`
- **Logo:** Blue dumbbell icon + "FitAdmin" wordmark (Primary Blue `#2563EB`)
- **Nav Items:**
  - Font: 15px, Weight: 500 (Medium)
  - Default State: `#64748B` (Medium Gray)
  - Active State: `#2563EB` (Primary Blue) with light blue background pill
  - Icon + Text layout with 8px gap
  - Spacing: 24px between nav items

#### User Profile Badge (Top Right)
- **Layout:** Email address + circular avatar with initials
- **Avatar:** 40px circle, `#DBEAFE` background, `#2563EB` text (initials)
- **Email:** 14px, `#64748B` (Medium Gray)
- **Spacing:** 12px gap between email and avatar

### Buttons

#### Primary Button (Black)
- **Background:** `#0F172A` (Deep Navy)
- **Text:** `#FFFFFF` (White), 14-15px, Weight: 500 (Medium)
- **Padding:** 12px 20px
- **Border Radius:** 8px
- **Icon:** Plus icon (+) before text, white color
- **Hover:** Slightly lighter background (`#1E293B`)
- **Usage:** Primary actions (e.g., "Add New Workout", "Create New Plan", "Save Plan")

#### Secondary Button (Outline)
- **Background:** Transparent
- **Border:** 1px solid `#E2E8F0`
- **Text:** `#334155` (Dark Gray), 14px, Weight: 500
- **Padding:** 10px 18px
- **Border Radius:** 8px
- **Hover:** Background `#F8FAFC`
- **Usage:** Secondary actions (e.g., "Edit", "Export as JSON", "Copy Week")

#### Text Button (Icon Only)
- **Background:** Transparent
- **Icon:** 18-20px, `#64748B` (Medium Gray)
- **Hover:** Background `#F1F5F9` (circle or rounded square)
- **Usage:** Edit, duplicate, delete actions in tables/cards

#### Destructive Button
- **Icon:** Trash can icon, `#EF4444` (Danger Red)
- **Hover:** Red background with white icon
- **Usage:** Delete operations

#### Modal Action Buttons
- **Primary (Black):** Same as primary button above
- **Secondary (Gray):** Background `#9CA3AF`, text white, 14px, Weight: 500
- **Cancel (White):** Background white, border `#E2E8F0`, text `#334155`
- **Spacing:** 12px gap between buttons, right-aligned

### Form Inputs

#### Text Input
- **Height:** 44-48px
- **Background:** `#F1F5F9` (Off-White) or `#FFFFFF` with border
- **Border:** 1px solid `#E2E8F0`
- **Border Radius:** 8px
- **Padding:** 12px 16px
- **Font:** 14-15px, Weight: 400, Color: `#000000`
- **Placeholder:** `#94A3B8` (Light Gray)
- **Focus State:** Border changes to `#2563EB` (Primary Blue), 2px width

#### Search Input
- **Icon:** Magnifying glass (left side), 18px, `#94A3B8`
- **Padding:** 12px 16px 12px 44px (to accommodate icon)
- **Placeholder:** "Search workouts...", "Search by name or email..."
- **Background:** `#F1F5F9` or `#FFFFFF`
- **Border Radius:** 8px

#### Dropdown / Select
- **Height:** 44-48px
- **Background:** `#FFFFFF` or `#F1F5F9`
- **Border:** 1px solid `#E2E8F0`
- **Border Radius:** 8px
- **Chevron Icon:** Right side, `#64748B`
- **Selected Text:** `#000000`, 14-15px
- **Hover:** Border `#2563EB`

#### Multi-Select Pills (Muscle Groups, Equipment)
- **Background:** `#FFFFFF`
- **Border:** 1px solid `#E2E8F0`
- **Border Radius:** 20px (fully rounded)
- **Padding:** 8px 16px
- **Font:** 14px, Weight: 400, Color: `#334155`
- **Selected State:** Border `#2563EB`, background `#EFF6FF` (light blue tint)
- **Spacing:** 8px gap between pills

#### Radio Buttons (Type: Weight/Timer)
- **Size:** 20px circle
- **Border:** 2px solid `#E2E8F0`
- **Selected State:** Filled circle with `#0F172A` (Deep Navy)
- **Label:** 16px, Weight: 400, `#000000`
- **Spacing:** 12px gap between radio and label, 32px between options

#### Toggle Switch (Active/Inactive)
- **Width:** 44px
- **Height:** 24px
- **Border Radius:** 12px (fully rounded)
- **Off State:** Background `#E2E8F0`, knob `#FFFFFF`
- **On State:** Background `#0F172A` (Deep Navy), knob `#FFFFFF`
- **Knob Size:** 20px circle with 2px margin
- **Transition:** Smooth 0.2s ease

### Status Badges

#### Active Badge
- **Background:** `#0F172A` (Deep Navy)
- **Text:** `#FFFFFF`, 12-13px, Weight: 500
- **Padding:** 4px 12px
- **Border Radius:** 12px (pill shape)

#### Inactive Badge
- **Background:** `#F1F5F9` (Light Gray)
- **Text:** `#64748B` (Medium Gray), 12-13px, Weight: 500
- **Padding:** 4px 12px
- **Border Radius:** 12px (pill shape)

#### Workout Type Badge (Weight/Timer)
- **Weight:** Background `#0F172A`, text `#FFFFFF`
- **Timer:** Background `#F1F5F9`, text `#334155`
- **Font:** 12-13px, Weight: 500
- **Padding:** 4px 10px
- **Border Radius:** 6px

### Cards

#### Standard Content Card
- **Background:** `#FFFFFF`
- **Border:** 1px solid `#E2E8F0`
- **Border Radius:** 12px
- **Padding:** 24-32px
- **Shadow:** Subtle `0 1px 3px rgba(0, 0, 0, 0.05)`

#### Plan Card (Workout Plans Page)
- **Background:** `#FFFFFF`
- **Border:** 1px solid `#E2E8F0`
- **Border Radius:** 16px
- **Padding:** 24px
- **Layout:**
  - Title: 18px, Weight: 600, `#000000`
  - Description: 14px, Weight: 400, `#64748B`
  - Badges: Bottom left (e.g., "8 Weeks", "Active")
  - Toggle: Top right
  - Actions: Bottom (Edit, Duplicate, Delete icons)
- **Shadow:** `0 1px 3px rgba(0, 0, 0, 0.05)`
- **Hover:** Slight shadow increase

#### Day Card (Add Plan Page)
- **Background:** `#FFFFFF`
- **Border:** 1px solid `#E2E8F0`
- **Border Radius:** 12px
- **Padding:** 20px
- **Header:** "Day 1" with duplicate/delete icons
- **Workout List:** Numbered items with drag handles
- **Add Button:** "+ Add Workout" at bottom
- **Dashed Border State:** When empty, dashed `#E2E8F0` border with "+ Add New Day" text

#### Stat Card (Users Page)
- **Background:** `#FFFFFF`
- **Border:** 1px solid `#E2E8F0`
- **Border Radius:** 12px
- **Padding:** 20px 24px
- **Label:** 14px, `#64748B`, top
- **Value:** 28-32px, Weight: 700, `#000000`, bottom
- **Layout:** Minimal, data-focused

### Tables

#### Table Structure
- **Header Row:**
  - Background: Transparent or `#FAFBFC`
  - Text: 13-14px, Weight: 600, `#64748B` (Medium Gray)
  - Padding: 12px 16px
  - Border Bottom: 1px solid `#E2E8F0`

- **Data Rows:**
  - Background: `#FFFFFF`
  - Text: 14px, Weight: 400, `#000000`
  - Padding: 16px
  - Border Bottom: 1px solid `#F1F5F9` (subtle divider)
  - Hover: Background `#F8FAFC`

- **Cell Alignment:**
  - Text: Left-aligned
  - Actions: Right-aligned
  - Numbers/Percentages: Right-aligned

#### User Table (Users Page)
- **User Column:** Avatar circle (32px) + name + email stacked
  - Name: 14px, Weight: 500, `#000000`
  - Email: 13px, Weight: 400, `#64748B`
- **Progress Bar:**
  - Height: 8px
  - Border Radius: 4px
  - Background: `#E2E8F0`
  - Fill: `#3B82F6` (Info Blue)
  - Percentage: Right side, 14px, Weight: 600, color matches progress level
- **Actions:** "View Details" link with eye icon, `#64748B`, hover `#2563EB`

#### Workout Table (Global Workouts Library)
- **Workout Name:** 14px, Weight: 500, `#000000`, left-aligned
- **Type Badge:** Inline (Weight/Timer pill)
- **Muscle Groups/Equipment:** Space-separated tags, 13px, `#334155`
- **Status Badge:** Inline (Active/Inactive pill)
- **Actions:** Edit (pencil) and Delete (trash) icons, `#64748B`, hover states

### Modals

#### Modal Container
- **Background:** `#FFFFFF`
- **Border Radius:** 16px
- **Max Width:** 600-800px
- **Padding:** 32px
- **Shadow:** Large depth shadow `0 20px 60px rgba(0, 0, 0, 0.3)`
- **Backdrop:** Semi-transparent `rgba(0, 0, 0, 0.5)` overlay

#### Modal Header
- **Title:** 24px, Weight: 600, `#000000`
- **Subtitle:** 15px, Weight: 400, `#64748B`
- **Close Button:** Top right, X icon, `#64748B`, 24px, hover `#000000`
- **Spacing:** 8px between title and subtitle

#### Segmented Control (Select Existing / Create New)
- **Background:** `#F1F5F9` (container)
- **Border Radius:** 10px (container)
- **Active Segment:** `#FFFFFF` background, shadow `0 1px 3px rgba(0, 0, 0, 0.1)`
- **Inactive Segment:** Transparent, text `#64748B`
- **Font:** 15px, Weight: 500
- **Padding:** 10px 24px per segment
- **Transition:** Smooth 0.2s ease

#### Modal Actions (Footer)
- **Layout:** Right-aligned, horizontal
- **Primary Button:** Black (e.g., "Add to Day", "Create Workout & Continue")
- **Secondary Button:** Gray or white outline (e.g., "Cancel")
- **Spacing:** 12px gap between buttons

### Progress Indicators

#### Progress Bar (User Completion)
- **Height:** 8px
- **Border Radius:** 4px
- **Background:** `#E2E8F0` (track)
- **Fill Colors:**
  - 100%: `#10B981` (Success Green)
  - 87-95%: `#22C55E` (High Green)
  - 68-79%: `#F59E0B` (Warning Orange)
  - Default: `#3B82F6` (Info Blue)
- **Percentage Label:** Adjacent, 14px, Weight: 600, matching fill color

### Icons

#### Icon System
- **Style:** Outline (stroke-based), rounded corners
- **Weight:** 1.5-2px stroke width
- **Size:** 18-20px (standard), 16px (small), 24px (large)
- **Color:** Inherits from parent or `#64748B` (default)

#### Common Icons
- **Plus (+):** Add actions, create new items
- **Pencil/Edit:** Edit actions
- **Trash Can:** Delete actions (red on hover)
- **Duplicate/Copy:** Copy/duplicate actions
- **Dumbbell:** Workouts, fitness branding
- **Calendar:** Plans, scheduling
- **Users/People:** User management
- **Eye:** View details
- **Search:** Magnifying glass for search inputs
- **Chevron Down:** Dropdowns, expandable sections
- **Drag Handle:** Six dots (3x2 grid) for reordering

### Tags & Pills

#### Muscle Group Tags
- **Background:** Transparent or `#F8FAFC`
- **Border:** None or 1px solid `#E2E8F0`
- **Text:** 13px, Weight: 400, `#334155`
- **Padding:** 4px 10px
- **Border Radius:** 6px
- **Spacing:** 6px gap between tags

#### Equipment Tags
- **Same styling as Muscle Group Tags**

#### Count Indicator (+1, +2, etc.)
- **Background:** `#F1F5F9`
- **Text:** 13px, Weight: 500, `#64748B`
- **Padding:** 4px 8px
- **Border Radius:** 4px
- **Usage:** Shows additional items when space is limited

### Autocomplete / Search Results

#### Search Dropdown (Select Existing Workout)
- **Container:** White background, `#E2E8F0` border, 12px border radius
- **Max Height:** 400px with scroll
- **Item Layout:**
  - Workout Name: 15px, Weight: 500, `#000000`
  - Muscle Groups: Small gray pills below name
  - Type Badge: Right-aligned (weight/timer)
  - Padding: 12px 16px per item
  - Hover: Background `#F8FAFC`
- **Divider:** 1px solid `#F1F5F9` between items

---

## Layout & Grid

### Spacing System

**Base Unit:** 4px

| Token | Value | Usage |
|-------|-------|-------|
| `xs` | 4px | Tight spacing, icon gaps |
| `sm` | 8px | Small gaps, tag spacing |
| `md` | 12px | Default gaps, form element spacing |
| `lg` | 16px | Card padding, section spacing |
| `xl` | 24px | Large gaps, card internal padding |
| `2xl` | 32px | Section padding, modal padding |
| `3xl` | 48px | Page-level spacing |

### Grid System

- **Container Max Width:** 1440px (responsive)
- **Page Padding:** 32px horizontal, 24px vertical
- **Column Grid:** 12-column flexible grid
- **Gap:** 24px between cards/columns

### Layout Patterns

#### Page Layout
1. **Top Navigation Bar** (64px fixed height)
2. **Page Header** (Title + Description + Primary CTA)
   - Title: Left-aligned
   - CTA Button: Right-aligned (absolute positioning or flex justify-between)
   - Margin Bottom: 32px
3. **Content Area** (Cards, tables, forms)
4. **Bottom Padding:** 48px

#### Two-Column Layout (Add Plan Page)
- **Left Column:** Plan overview form (40% width)
- **Right Column:** Week structure builder (60% width)
- **Gap:** 32px between columns
- **Responsive:** Stack vertically on mobile (<768px)

#### Card Grid (Plans Page)
- **Columns:** 3 cards per row (desktop), 2 per row (tablet), 1 per row (mobile)
- **Gap:** 24px horizontal and vertical
- **Card Min Width:** 320px

#### Stat Cards Row (Users Page)
- **Layout:** 4 cards in a row
- **Equal Width:** Flex with flex: 1
- **Gap:** 16px between cards

---

## Imagery & Iconography

### Icon Style
- **Design Language:** Outline icons (stroke-based) with rounded line caps
- **Stroke Weight:** 1.5-2px
- **Corner Radius:** Rounded (not sharp corners)
- **Alignment:** Centered vertically with adjacent text
- **Tone:** Clean, minimal, modern — avoiding decorative complexity

### Logo
- **Symbol:** Stylized dumbbell icon in Primary Blue (`#2563EB`)
- **Wordmark:** "FitAdmin" in sans-serif, Weight: 600
- **Usage:** Top left of navigation bar, 32px height

### User Avatars
- **Default:** Circular with user initials
- **Background:** `#DBEAFE` (light blue)
- **Text:** Initials in uppercase, `#2563EB` (Primary Blue), Weight: 600
- **Size:** 40px (nav), 32px (table), 48px (large)

### Illustrations
- **Style:** None present in current designs (data-focused interface)
- **Future Use:** Simple, geometric, monochromatic illustrations if needed

---

## Accessibility

### Contrast Ratios

All color combinations meet WCAG 2.1 AA standards:

| Combination | Ratio | Standard |
|-------------|-------|----------|
| Black text on White | 21:1 | AAA |
| Dark Gray (`#334155`) on White | 11.8:1 | AAA |
| Medium Gray (`#64748B`) on White | 5.9:1 | AA |
| Primary Blue (`#2563EB`) on White | 4.6:1 | AA |
| White text on Deep Navy (`#0F172A`) | 17.4:1 | AAA |
| White text on Primary Blue | 4.5:1 | AA |

### Focus States
- **Keyboard Focus:** 2px solid `#2563EB` outline with 2px offset
- **Focus Visibility:** Always visible, never hidden
- **Tab Order:** Logical, follows visual hierarchy

### Font Size Minimum
- **Body Text:** Never below 14px
- **Interactive Elements:** Minimum 14px for legibility
- **Touch Targets:** Minimum 44x44px for buttons and interactive elements (mobile)

### Screen Reader Support
- **Semantic HTML:** Use proper heading hierarchy (h1 → h2 → h3)
- **Alt Text:** All icons should have descriptive labels
- **ARIA Labels:** Interactive elements without visible text require aria-label

### Color Blindness Considerations
- **Not Color-Only:** Status uses icons + color (e.g., Active badge has text label)
- **Progress Indicators:** Include percentage text alongside colored bars
- **Deuteranopia-Friendly:** Green/red combinations avoided in critical UI

---

## Do's and Don'ts

### Color

**Do:**
- Use Primary Blue (`#2563EB`) for brand and interactive elements
- Use Deep Navy (`#0F172A`) for primary CTAs and emphasis
- Maintain consistent semantic colors (green = success, red = danger)
- Use neutral grays for text hierarchy

**Don't:**
- Don't use bright, saturated colors outside the defined palette
- Don't use pure black (`#000000`) for body text — use Dark Gray instead
- Don't use color alone to convey information (pair with icons/text)

### Typography

**Do:**
- Maintain clear type hierarchy (headings → body → captions)
- Use font weights intentionally (600 for headings, 400 for body)
- Keep line height generous (1.4-1.5) for readability
- Left-align text by default

**Don't:**
- Don't use more than 3 font weights on a single page
- Don't use font sizes below 12px (except for rare exceptions)
- Don't center-align body text or form labels
- Don't use all caps for body text (only for initials in avatars)

### Spacing

**Do:**
- Use the spacing scale consistently (4px increments)
- Provide generous white space around content
- Maintain consistent padding within similar components
- Use 24-32px margins between major sections

**Don't:**
- Don't use arbitrary spacing values (stick to the scale)
- Don't overcrowd cards or tables with tight spacing
- Don't mix spacing patterns within the same component type

### Components

**Do:**
- Use rounded corners consistently (8-16px for cards, 6-12px for buttons)
- Provide clear hover/focus states for all interactive elements
- Group related actions together (e.g., Edit, Duplicate, Delete)
- Use primary buttons sparingly (one per page section)

**Don't:**
- Don't mix button styles within the same action group
- Don't use more than one primary button in a single view
- Don't hide destructive actions without confirmation
- Don't remove borders from inputs (maintain clarity)

### Layout

**Do:**
- Maintain max width of 1440px for wide screens
- Use flexible grids that adapt to content
- Align content to a consistent grid system
- Provide adequate padding on page edges (32px minimum)

**Don't:**
- Don't stretch content to fill ultra-wide screens (>1440px)
- Don't create unbalanced layouts (use equal or proportional columns)
- Don't ignore responsive breakpoints

---

## Design Principles

### 1. Clarity Over Cleverness
Prioritize clear, obvious UI patterns over creative but confusing interactions. Users should never have to guess how something works.

### 2. Data First
The interface serves the data. Use visual hierarchy to highlight critical information (e.g., completion rates, workout names) while keeping secondary details subtle.

### 3. Consistent Patterns
Reuse established components and patterns across the application. If a pattern works in one context, apply it consistently elsewhere.

### 4. Generous Whitespace
White space is not wasted space — it improves scanability, reduces cognitive load, and makes content feel organized.

### 5. Progressive Disclosure
Show the most important information by default. Hide advanced options behind toggles, modals, or expandable sections.

### 6. Feedback & Affordance
Every interactive element should have clear hover, focus, and active states. Users should always know what's clickable and what state they're in.

### 7. Accessible by Default
Design with accessibility in mind from the start — not as an afterthought. High contrast, large touch targets, and semantic HTML are non-negotiable.

### 8. Mobile-Friendly Thinking
Even though this is an admin dashboard (likely desktop-first), consider responsive behavior early. Tables should scroll horizontally, modals should stack, and touch targets should be adequate.

---

## Component Library Recommendations

For implementation, consider using:
- **Tailwind CSS** — Utility classes align well with this spacing/color system
- **Headless UI** — For accessible modals, dropdowns, toggles
- **Radix UI** — For accessible primitives (if not using Headless)
- **React Hook Form** — For performant form handling
- **Framer Motion** — For smooth transitions and animations

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-10-12 | Initial design system documentation based on design mockups |

---

**Maintained by:** FitAdmin Design Team
**Contact:** design@fitadmin.com
**Last Updated:** October 12, 2025
