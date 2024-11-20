require("prototypes.prototypes")

data.raw["gui-style"].default["outer_frame"] =  {
    type = "frame_style",
    parent = "invisible_frame",
    graphical_set = { shadow = default_shadow } ---@diagnostic disable-line: undefined-global
}
