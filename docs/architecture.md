# Basics
- Basic functinality should match smart-filename as it was in the tigger04/summarize-text project before we split it
- The only dependencies should be:
  - yq to parse yaml
  - fd for finding files
  - tigger04/shell-and-scripting errors : we should leverage its scripting helpers such as `info`, `warn`, `die` etc
  - the library that the old smart-filename relied on can be merged into our new script, `smart-rename`, but only the parts we require
  - so that `smart-rename` is a self contained script. It is rather simple

# A reminder of how the script was working and should continue to work
- `smart-filename [REGEX_1] .. [REGEX_n]` - search regex in teh current dir using fd, then iterate one by one with `ok_confirm`, then when we find a suitable name from our AI model, `confirm_cmd_execute`
- OPTIONS:
  - `-r/--recursive` - search recursive, 
  - `-g/--glob` - search glob instead of regex
  - `-y/--yes` - rename without prompting for confirmation
