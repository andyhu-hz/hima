local common = {}

function common.print_table(table) 
    for k, v in pairs(table) do
        print("key = " .. k .. ", value = " .. v)
    end
end

return common
