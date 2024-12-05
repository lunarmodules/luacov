local max_iterations = 100
local width = 80
local height = 40
local x_min, x_max = -2.0, 1.0
local y_min, y_max = -1.0, 1.0

local function mandelbrot(cx, cy)
    local x, y = 0, 0
    local iteration = 0

    while x*x + y*y <= 4 and iteration < max_iterations do
        local x_new = x*x - y*y + cx
        y = 2*x*y + cy
        x = x_new
        iteration = iteration + 1
    end

    return iteration
end

local function draw_mandelbrot()
    for py = 0, height - 1 do
        local y = y_min + (y_max - y_min) * py / (height - 1)
        local line = ""

        for px = 0, width - 1 do
            local x = x_min + (x_max - x_min) * px / (width - 1)
            local iteration = mandelbrot(x, y)

            if iteration == max_iterations then
                line = line .. "#"
            else
                local shade = math.floor((iteration / max_iterations) * 10)
                line = line .. string.sub(" .:-=+*#%@", shade + 1, shade + 1)
            end
        end

        print(line)
    end
end

draw_mandelbrot()
