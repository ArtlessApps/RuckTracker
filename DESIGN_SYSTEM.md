# MARCH App - Design System Documentation
**For Website Designer Reference**

---

## Brand Identity

**App Name:** MARCH  
**Tagline:** WALK STRONGER  
**Description:** Ruck training and workout tracking application

**Brand Personality:**
- Tactical and military-inspired
- Strong, bold, and disciplined
- Clean and minimalist
- Fitness-focused and performance-driven

---

## Color Palette

### Primary Colors

| Color Name | Hex Code | RGB | Usage |
|------------|----------|-----|-------|
| **Primary Main** | `#D4704A` | rgb(212, 112, 74) | Main brand color - Burnt Sienna/Terracotta |
| **Primary Light** | `#E8886B` | rgb(232, 136, 107) | Lighter accent, hover states |
| **Primary Medium** | `#D4704A` | rgb(212, 112, 74) | Same as Primary Main |

### Accent Colors

| Color Name | Hex Code | RGB | Usage |
|------------|----------|-----|-------|
| **Accent Teal** | `#6B9B9E` | rgb(107, 155, 158) | Secondary accent, highlights |
| **Accent Green** | `#88A886` | rgb(136, 168, 134) | Success states, positive actions |
| **Accent Cream** | `#F2E8DC` | rgb(242, 232, 220) | Warm neutral, card backgrounds |
| **Clay** | `#E8886B` | rgb(232, 136, 107) | Same as Primary Light |

### Background Colors

| Color Name | Hex Code | RGB | Usage |
|------------|----------|-----|-------|
| **Background Dark** | `#2D2D2D` | rgb(45, 45, 45) | Dark mode background, headers |
| **Background Light** | `#F5F3F0` | rgb(245, 243, 240) | Light mode background |
| **Off White** | `#F5F2F0` | rgb(245, 242, 240) | Alternative light background |
| **White** | `#FFFFFF` | rgb(255, 255, 255) | Pure white for cards and overlays |

### Text Colors

| Color Name | Hex Code | RGB | Usage |
|------------|----------|-----|-------|
| **Text Primary** | `#000000` / `#FFFFFF` | Black/White | Main text (context-dependent) |
| **Text Secondary** | `#5A5A5A` | rgb(90, 90, 90) | Secondary text, labels |
| **Text Tertiary** | `#8B8680` | rgb(139, 134, 128) | Tertiary text, placeholders |
| **Warm Gray** | `#8B8680` | rgb(139, 134, 128) | Muted text, disabled states |

### Color Usage Guidelines

**Primary Main (`#D4704A`):**
- Hero buttons and CTAs
- App branding and logo
- Important highlights
- Active states

**Accent Teal (`#6B9B9E`):**
- Secondary buttons
- Icons and decorative elements
- Links and interactive elements

**Background Dark (`#2D2D2D`):**
- Dark mode interface
- Navigation bars
- Splash screen background
- Header sections

**Background Light (`#F5F3F0`):**
- Main light mode background
- Content areas
- Cards and panels

---

## Typography

### Font Family

**Primary Font:** **San Francisco (SF Pro)**
- Native iOS system font
- Fallback: System font stack
- Web equivalent: `-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif`

**Alternative Recommendation for Web:**
- **Inter** - Similar geometric proportions to SF Pro
- **DM Sans** - Clean, modern alternative
- **Rubik** - Bold and geometric option

### Font Weights

| Weight | Value | Usage |
|--------|-------|-------|
| **Black** | 900 | Large headings, brand name "MARCH" |
| **Heavy** | 800 | Section headers |
| **Bold** | 700 | Emphasis, subheadings |
| **Semibold** | 600 | Labels, small caps text |
| **Medium** | 500 | Body text, button labels |
| **Regular** | 400 | Standard body text |

### Typography Scale

#### Display & Branding
```
Brand Name (MARCH): 
- Size: 72px | Weight: Black (900) | Letter Spacing: 2px

Tagline (WALK STRONGER):
- Size: 18px | Weight: Medium (500) | Letter Spacing: 4px

Hero Heading:
- Size: 46px | Weight: Heavy (800) | Letter Spacing: 2px
```

#### Headings
```
H1 (Page Title):
- Size: 28-32px | Weight: Bold (700) | Letter Spacing: 0px

H2 (Section Header):
- Size: 22-24px | Weight: Bold (700) | Letter Spacing: 0px

H3 (Card Title):
- Size: 18-20px | Weight: Semibold (600) | Letter Spacing: 0px

H4 (Small Label):
- Size: 16px | Weight: Semibold (600) | Letter Spacing: 1px
```

#### Body Text
```
Body Large:
- Size: 17px | Weight: Regular (400) | Line Height: 1.5

Body Regular:
- Size: 15-16px | Weight: Regular (400) | Line Height: 1.5

Body Small:
- Size: 14px | Weight: Regular (400) | Line Height: 1.4

Caption:
- Size: 12-13px | Weight: Regular (400) | Line Height: 1.3
```

#### Special Text
```
Metric Display (Large Numbers):
- Size: 100px | Weight: Medium (500)

Metric Units:
- Size: 40px | Weight: Regular (400)

Small Caps Labels:
- Size: 14-16px | Weight: Semibold (600) | Letter Spacing: 2px | Transform: Uppercase
```

### Typography Guidelines

1. **Letter Spacing:**
   - Brand elements and labels: 2-4px
   - All-caps text: 1-2px
   - Regular text: 0px (default)

2. **Line Height:**
   - Headings: 1.2-1.3
   - Body text: 1.5-1.6
   - Captions: 1.3-1.4

3. **Text Alignment:**
   - Primary: Left-aligned
   - Headings and CTAs: Center-aligned when appropriate
   - Metrics and numbers: Center-aligned

---

## UI Components

### Buttons

**Primary Button (Hero CTA):**
- Background: `#D4704A` (Primary Main)
- Text: White
- Font Weight: Semibold (600)
- Border Radius: 12-16px
- Padding: 16-20px vertical, 32-40px horizontal
- Shadow: Subtle (optional)

**Secondary Button:**
- Background: `#6B9B9E` (Accent Teal) or White with border
- Text: Black or Primary Main
- Font Weight: Semibold (600)
- Border: 2px solid (if outlined)
- Border Radius: 12-16px
- Padding: 14-18px vertical, 28-36px horizontal

**Text Button:**
- Background: Transparent
- Text: `#D4704A` (Primary Main)
- Font Weight: Medium (500)
- Underline on hover

### Cards

**Style:**
- Background: White or `#F2E8DC` (Accent Cream)
- Border Radius: 16-20px
- Padding: 20-24px
- Shadow: Soft, subtle elevation
- Border: None or 1px solid light gray

### Spacing System

**Base Unit:** 4px

```
xs:  4px
sm:  8px
md:  12px
lg:  16px
xl:  20px
2xl: 24px
3xl: 32px
4xl: 40px
5xl: 48px
6xl: 60px
```

### Border Radius

```
Small:  8px   (inputs, tags)
Medium: 12px  (buttons, small cards)
Large:  16px  (cards, modals)
XLarge: 20px  (hero cards)
Round:  999px (pills, badges)
```

### Shadows

```
Subtle:
- box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08)

Medium:
- box-shadow: 0 4px 16px rgba(0, 0, 0, 0.12)

Strong:
- box-shadow: 0 8px 24px rgba(0, 0, 0, 0.16)
```

---

## Visual Style Guidelines

### Design Principles

1. **Clean & Minimal:**
   - Lots of whitespace
   - Focused content hierarchy
   - Uncluttered layouts

2. **Bold & Confident:**
   - Strong typography
   - High contrast
   - Clear CTAs

3. **Tactical & Professional:**
   - Military-inspired aesthetics
   - Performance-oriented
   - Serious and disciplined tone

4. **Mobile-First:**
   - Touch-friendly targets (minimum 44x44px)
   - Large, readable text
   - Simple navigation

### Icons & Imagery

**Icon Style:**
- Line icons preferred
- Stroke weight: 2px
- Style: SF Symbols (iOS native) or similar
- Size: 20-24px for inline, 32-48px for featured

**Photography:**
- High-contrast, dramatic lighting
- Outdoor/rugged settings
- Focus on action and movement
- Tactical/military aesthetic

**Color Treatment:**
- Duotone with Primary Main (`#D4704A`) and dark backgrounds
- High contrast black and white
- Warm, earthy tones

---

## Brand Assets

### Logo Usage

**Primary Lockup:**
```
MARCH
WALK STRONGER
```

**Brand Name:**
- Always uppercase: "MARCH"
- Color: `#D4704A` (Primary Main)
- Font Weight: Black (900)
- Letter Spacing: 2px

**Tagline:**
- Always uppercase: "WALK STRONGER"
- Color: White (on dark) or `#2D2D2D` (on light)
- Font Weight: Medium (500)
- Letter Spacing: 4px

### Brand Voice

**Tone:**
- Motivational but not aggressive
- Supportive and encouraging
- Professional and knowledgeable
- Action-oriented

**Language:**
- Direct and concise
- Active voice
- Military/tactical terminology where appropriate
- Focus on strength, endurance, progress

---

## Accessibility

### Contrast Ratios

Ensure WCAG AA compliance (minimum 4.5:1 for normal text, 3:1 for large text):

- Primary Main on White: ✓ Passes
- White on Background Dark: ✓ Passes
- Text Secondary on White: ✓ Passes
- Accent Teal on White: ⚠️ Check for small text

### Interactive Elements

- Minimum touch target: 44x44px
- Clear focus states (outline or background change)
- Sufficient spacing between interactive elements

---

## Dark Mode Considerations

**Background:**
- Primary: `#2D2D2D` (Background Dark)
- Secondary: `#1A1A1A` (Darker variation)

**Text:**
- Primary: White (`#FFFFFF`)
- Secondary: `#CCCCCC`
- Tertiary: `#999999`

**Accents:**
- Primary Main: Keep `#D4704A` (good contrast)
- Adjust other colors as needed for readability

---

## Example Color Combinations

### High Impact Hero Section
- Background: `#2D2D2D`
- Primary Text: White
- Accent: `#D4704A`

### Clean Content Section
- Background: `#F5F3F0`
- Primary Text: `#2D2D2D`
- Accent: `#D4704A`
- Cards: White with `#F2E8DC` highlights

### Call-to-Action Section
- Background: `#D4704A`
- Text: White
- Button: `#6B9B9E` or White outlined

---

## Additional Resources

### Web Font Recommendations

**Primary Choice: Inter**
```css
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&display=swap');

font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
```

**Alternative: DM Sans**
```css
@import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;700;900&display=swap');

font-family: 'DM Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
```

### CSS Variables Setup

```css
:root {
  /* Primary Colors */
  --color-primary-main: #D4704A;
  --color-primary-light: #E8886B;
  
  /* Accent Colors */
  --color-accent-teal: #6B9B9E;
  --color-accent-green: #88A886;
  --color-accent-cream: #F2E8DC;
  
  /* Backgrounds */
  --color-bg-dark: #2D2D2D;
  --color-bg-light: #F5F3F0;
  --color-off-white: #F5F2F0;
  
  /* Text */
  --color-text-primary: #000000;
  --color-text-secondary: #5A5A5A;
  --color-text-tertiary: #8B8680;
  
  /* Spacing */
  --spacing-xs: 4px;
  --spacing-sm: 8px;
  --spacing-md: 12px;
  --spacing-lg: 16px;
  --spacing-xl: 20px;
  --spacing-2xl: 24px;
  --spacing-3xl: 32px;
  --spacing-4xl: 40px;
  
  /* Border Radius */
  --radius-sm: 8px;
  --radius-md: 12px;
  --radius-lg: 16px;
  --radius-xl: 20px;
}
```

---

## Questions or Clarifications?

For any design questions, reference the iOS app directly or contact the development team. This design system is extracted from the native app and should maintain visual consistency across all platforms.

**Version:** 1.0  
**Last Updated:** November 2025  
**Platform:** Web Design Reference (from iOS App)

