## 2024-04-17 - Icon-only Buttons Need Tooltips
**Learning:** Icon-only buttons (like the `||` pause button) in Godot need explicit `tooltip_text` to act as accessible labels (similar to ARIA labels on the web) and `mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND` to provide visual affordance for interaction.
**Action:** Always verify if a Godot button has meaningful text or an icon. If it's just an icon or non-descriptive text, set `tooltip_text`. Add `CURSOR_POINTING_HAND` to UI elements meant to be clicked to enhance UX.
