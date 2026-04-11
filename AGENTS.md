# Repository Development Guidelines

## Core Principle

This repository is maintained as a fork and should stay as easy as possible to sync with the upstream project.

When implementing changes, prioritize approaches that keep the diff against upstream small and easy to review. The goal is not to make the code as short as possible, but to make the fork easier to maintain over time.

## Preferred Development Style

- Prefer extension points, wrapper layers, adapters, helper types, and new files over deep edits to existing upstream files.
- Keep changes to existing implementation files to the minimum required for the feature to work.
- It is acceptable for the architecture to be slightly more indirect or verbose if that helps reduce the amount of upstream code that must be modified.
- New files are welcome when they help isolate fork-specific behavior from upstream code.
- Avoid broad refactors of existing upstream code unless they are truly necessary.

## Decision Rule

If there are multiple ways to implement a feature, prefer the one that:

1. minimizes changes to existing upstream files,
2. keeps fork-specific behavior isolated,
3. reduces the chance of merge conflicts during future upstream syncs,
4. preserves existing behavior unless the change is explicitly intended.

## Practical Guidance

- Treat existing upstream files as stable surfaces whenever possible.
- Add small integration points instead of rewriting core flows.
- Keep UI changes minimal unless they are required for the feature.
- Avoid incidental cleanup or unrelated style changes in touched upstream files.
- Do not expand the scope of changes just because a broader refactor seems cleaner.

## Expected Outcome

Development in this repository should follow a "minimum existing diff" concept:

- implement what is needed,
- isolate fork-specific behavior,
- minimize impact on upstream implementation,
- keep future upstream sync work as simple as possible.
