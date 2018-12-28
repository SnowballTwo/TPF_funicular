
local mat2 = { }

function mat2.mul(a, b)
    return {
        {
            a[1][1] * b[1][1] + a[1][2] * b[2][1],
            a[1][1] * b[1][2] + a[1][2] * b[2][2],            
        },
        {
            a[2][1] * b[1][1] + a[2][2] * b[2][1],
            a[2][1] * b[1][2] + a[2][2] * b[2][2],            
        }        
    }
end

function mat2.det(m)
    return 
        m[1][1] * m[2][2] - 
        m[1][2] * m[2][1]
end

function mat2.solve(A, b)
    local denominator = mat2.det(A)
    local x1 =
        mat2.det(
        {
            {b[1], A[1][2]},
            {b[2], A[2][2]}            
        }
    ) / denominator

    local x2 =
        mat2.det(
        {
            {A[1][1], b[1]},
            {A[2][1], b[2]},
        }
    ) / denominator   

    return {x1, x2}
end

return mat2
