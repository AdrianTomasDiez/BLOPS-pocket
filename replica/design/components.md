# Components

## Button
variants primary, secondary, ghost, danger
sizes sm 32px, md 40px, lg 48px
states default, pressed, focus-visible (2px ring accent), disabled, loading
tokens bg accent/surface, text on-accent/text, radius md, font sm/600
a11y real button, visible focus, loading keeps label for screen readers
used on S01-S14

## Toggle
variants on/off
states default, disabled
tokens surface/border, radius pill
a11y role switch, aria-checked
used on S04

## Slider
variants sensitivity, volume, quality
states default, dragging, disabled
tokens track border, thumb accent, radius pill
a11y role slider, aria-valuenow/min/max
used on S04

## Progress Bar
variants determinate, indeterminate
states running, complete, error
tokens surface, accent fill, radius sm
a11y role progressbar, aria-valuenow
used on S01, S03, S08

## File Row
variants verified, missing, mismatched
states default, selected
tokens surface, border, text/text-muted
a11y role listitem, status text not color-only
used on S03

## Dialog / Modal
variants info, warning, error
states open, closed
tokens surface, border, radius lg, shadow pop
a11y focus trap, Esc to close, aria-modal
used on S01, S03, S14

## Toast
variants success, error
states show, hide
tokens surface, accent/danger, radius md
a11y role status, aria-live polite
used on S01-S03

## Map Card
variants available, locked
states default, selected
tokens surface, border, accent outline, radius lg
a11y button role, aria-pressed
used on S07

## HUD: Ammo Counter
states normal, low, empty
tokens hud-bg, hud-text, hud-accent
a11y not interactive; text alternative in settings
used on S09

## HUD: Health / Downed
states alive, downed
tokens hud-bg, hud-text, danger
a11y status text
used on S09

## HUD: Points
states default
tokens hud-bg, hud-text
used on S09

## HUD: Round Counter
states default
tokens hud-bg, hud-text
used on S09

## HUD: Perk Icons
states 0-4 perks
tokens hud-bg, hud-accent
used on S09

## HUD: Power-Up Banner
states show, hide
tokens hud-bg, hud-accent
used on S09

## Touch Control: Virtual Stick
states default, active
tokens surface, border, accent knob
a11y not screen-reader operable; gamepad alternative
used on S09

## Touch Control: Fire Button
states default, pressed
tokens danger, on-accent
used on S09

## Touch Control: Aim
states default, pressed
tokens surface, accent
used on S09

## Touch Control: Action Buttons
variants jump, crouch, reload, switch
states default, pressed, cooldown
tokens surface, border, text
used on S09