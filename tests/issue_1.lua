function test1()
    local thing = nil -- MISSED BY LUACOV
    print("test1")
end
test1()

function test2()
    local stuff = function (x) return x end
    local thing = stuff({
        b = { name = 'bob',
        },
        -- comment
    }) -- MISSED BY LUACOV
    print("test2")
end
test2()

function test3()
    if true then -- MISSED BY LUACOV
        print("test3")
    end
end
test3()

function test4()
    while true do -- MISSED BY LUACOV
        print("test4")
        break
    end
end
test4()

-- My own addition:

function test5()
    local stuff = function (x) return x end
    local thing = stuff({
        b = { name = 'bob',
        },
        -- comment
    }
    ) -- MISSED BY LUACOV
    print("test5")
end
test5()
