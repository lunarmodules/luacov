-- Samurai Name and Wisdom Generator

-- Function to generate a random samurai name
function generateSamuraiName()
    local firstNames = {"Takeda", "Oda", "Tokugawa", "Uesugi", "Shimazu", "Mori", "Date", "Sanada", "Hattori", "Honda"}
    local lastNames = {"Nobunaga", "Ieyasu", "Kenshin", "Yoshihiro", "Yoshimoto", "Masamune", "Yukimura", "Hanzo", "Tadakatsu", "Shingen"}

    local firstName = firstNames[math.random(#firstNames)]
    local lastName = lastNames[math.random(#lastNames)]

    return firstName .. " " .. lastName
end

-- Function to generate a random samurai wisdom
function generateSamuraiWisdom()
    local wisdoms = {
        "The bamboo that bends is stronger than the oak that resists.",
        "Victory comes to those who make the last move.",
        "Patience is the warrior's greatest weapon.",
        "A samurai's mind is as sharp as his blade.",
        "In the midst of chaos, there is also opportunity.",
        "The journey of a thousand miles begins with a single step.",
        "To know oneself is to study oneself in action with another person.",
        "The ultimate aim of martial arts is not having to use them.",
        "A warrior is worthless unless he rises above others and stands strong in the midst of a storm.",
        "The way of the warrior is resolute acceptance of death."
    }

    return wisdoms[math.random(#wisdoms)]
end

-- Function to display ASCII art of a samurai
function displaySamuraiArt()
    print("        O")
    print("       /|\\")
    print("      / | \\")
    print("     /  |  \\")
    print("    /   |   \\")
    print("   /    |    \\")
    print("  /     |     \\")
    print(" /      |      \\")
    print("/_______|_______\\")
    print("       / \\")
    print("      /   \\")
    print("     /     \\")
    print("    /       \\")
    print("   /         \\")
    print("  /           \\")
    print(" /             \\")
    print("/_______________\\")
end

-- Main function to generate and display samurai name and wisdom
function main()
    math.randomseed(os.time())

    print("Welcome to the Samurai Name and Wisdom Generator!")
    print("-----------------------------------------------")

    local samuraiName = generateSamuraiName()
    local samuraiWisdom = generateSamuraiWisdom()

    print("\nYour Samurai Name:")
    print("------------------")
    print(samuraiName)

    print("\nSamurai Wisdom:")
    print("---------------")
    print(samuraiWisdom)

    print("\nSamurai Art:")
    print("------------")
    displaySamuraiArt()
end

-- Run the main function
main()
