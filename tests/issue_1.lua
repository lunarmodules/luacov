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

function test6()
	-- MISSED BY LUACOV
	if true then -- MISSED BY LUACOV
	end -- MISSED BY LUACOV
	print("test6")
end
test6()

function test7()
    local a, b = 1,2
    if
        a < b
    then -- MISSED BY LUACOV
      a = b
    end -- MISSED BY LUACOV
    print("test7")
end
test7()

function test8()
    local a,b = 1,2
    if a < b then
      a = b
    end; -- MISSED BY LUACOV

    local function foo(f) f() end
    foo(function()
      a = b
    end) -- MISSED BY LUACOV

    print("test8")
end
test8()

function test9()
    local function foo(f)
        return function() -- MISSED BY LUACOV
            a = a
        end
    end
    foo()()

    print("test9")
end
test9()

function test10()
    local s = {
        a = 1; -- MISSED BY LUACOV
        b = 2, -- MISSED BY LUACOV
        c = 3  -- MISSED BY LUACOV
    }

    print("test10")
end
test10()

function test11()
    local function foo(f)
        return 1, 2, function() -- MISSED BY LUACOV
            a = a
        end
    end
    local a,b,c = foo()
    c()

    print("test11")
end
test11()
