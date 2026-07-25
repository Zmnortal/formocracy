# Interactive work calendar

The office calendar uses one shared schedule rule: day 1 is Monday, Monday through Saturday are duty days, and Sunday is the single rest day in each seven-day cycle.

The small wall calendar remains an in-world object rather than a HUD. It is enlarged, shows the current 35-day page, circles every completed day in red, and frames the current day in brass. Clicking it opens a larger paper calendar above the workbench. The expanded view states the current day number, weekday, duty/rest status, and the “work six, rest one” rule.

Schedule arithmetic lives in `WorkCalendarSchedule`, independent from the visual module, so later scene routing can reuse the same rule when a true rest-day flow is implemented. This change exposes and communicates the rule without changing the existing cross-day scene sequence.

The calendar overlay consumes ESC before the pause menu, has no automatic closing timer, and refreshes from `WorkdayState.day_number` every time it opens.
