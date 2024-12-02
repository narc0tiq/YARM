local hsv_module = {}

---@alias hsv_color {h:number,s:number,v:number}
---@alias rgb_color {r:number,g:number,b:number}

---Turn a HSV (hue, saturation, value) color to RGB. HSV may be given as a table
---with "h", "s", and "v" members, or as individual members. H,S, and V are expected
---to be in the range 0.0-1.0, where 1.0 corresponds to 360 degrees, 100%, and 100%,
---respectively.
---@param h number|hsv_color
---@param s number?
---@param v number?
---@return rgb_color
function hsv_module.to_rgb(h, s, v)
    if type(h) == "table" then
        h, s, v = h.h, h.s, h.v
    end
    local r, g, b
    local i = math.floor(h * 6);
    local f = h * 6 - i;
    local p = v * (1 - s);
    local q = v * (1 - f * s);
    local t = v * (1 - (1 - f) * s);
    i = i % 6
    if i == 0 then
        r, g, b = v, t, p
    elseif i == 1 then
        r, g, b = q, v, p
    elseif i == 2 then
        r, g, b = p, v, t
    elseif i == 3 then
        r, g, b = p, q, v
    elseif i == 4 then
        r, g, b = t, p, v
    elseif i == 5 then
        r, g, b = v, p, q
    end
    return { r = r, g = g, b = b }
end

---Turn an RGB color into an HSV table with values in the 0..1 range (h == 1 meaning 360 degrees)
---@param rgb rgb_color
---@return hsv_color
function hsv_module.from_rgb(rgb)
    local r, g, b = rgb.r, rgb.g, rgb.b
    -- Normalize to 0..1 if in the 0..255 color space
    if r > 1 or g > 1 or b > 1 then
        r = r/255
        g = g/255
        b = b/255
    end
    local max = math.max(r, g, b)
    local min = math.min(r, g, b)
    local h, s, v = max, max, max
    local d = max - min
    s = max == 0 and 0 or d / max

    if max == min then
        h = 0
    else
        if r == max then
            h = (g-b) / d + (g < b and 6 or 0)
        elseif g == max then
            h = (b-r) / d + 2
        elseif b == max then
            h = (r-g) / d + 4
        end
        h = h/6
    end

    return { h = h, s = s, v = v }
end

---Linearly interpolate between two numbers (in any direction). Used to generate
---intermediate values between `from` and `to` at a fractional point between them
---(e.g., 0.33 of the way between, from 0 to 100 will return 33).
---@param from number The number corresponding to a factor of 0.0
---@param to number The number corresponding to a factor of 1.0
---@param factor number Position between 0.0 and 1.0 to intepolate to. Will be clamped to be in-bounds.
local function number_lerp(from, to, factor)
  if factor > 1 then factor = 1 end
  if factor < 0 then factor = 0 end
  return (1 - factor) * from + factor * to
end

---Linearly interpolate between two HSV colors by the shortest path around the cylinder
---(i.e., forward or reverse HSV gradient, depending on which direction is closer)
---S and V components use plain linearity.
---NB: HSV colors are defined with the hue in a range of 0.0 to 1.0 corresponding to 0-360 degrees
---@param from hsv_color The color corresponding to a factor of 0.0
---@param to hsv_color The color corresponding to a factor of 1.0
---@param factor number Position between 0.0 and 1.0 to interpolate to
---@return hsv_color
function hsv_module.lerp(from, to, factor)
  local fore_diff = (1+to.h - from.h) % 1
  local back_diff = (1+from.h - to.h) % 1

  local h = 0
  if fore_diff < back_diff then
    h = to.h > from.h and number_lerp(from.h, to.h, factor) or (number_lerp(from.h, 1+to.h, factor) % 1)
  else
    h = from.h > to.h and number_lerp(from.h, to.h, factor) or (number_lerp(1+from.h, to.h, factor) % 1)
  end

  return {
    h=h,
    s=number_lerp(from.s, to.s, factor),
    v=number_lerp(from.v, to.v, factor),
  }
end

return hsv_module