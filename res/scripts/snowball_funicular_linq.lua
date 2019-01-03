local linq = {}

function linq.select(table, selector)
    local result = {}
    for i = 1, #table do
        result[#result + 1] = selector(table[i])
    end
    return result
end

return linq
