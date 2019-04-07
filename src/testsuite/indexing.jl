function test_indexing(AT)
    # TODO: more fine-grained allowscalar within test_indexing
    GPUArrays.@allowscalar @testset "indexing" begin
        for T in (Float32, Int32#=, SVector{3, Float32}=#)
            @testset "Indexing with $T" begin
                x = rand(T, 32)
                src = AT(x)
                for (i, xi) in enumerate(x)
                    @test src[i] == xi
                end
                @test Array(src[1:3]) == x[1:3]
                @test Array(src[3:end]) == x[3:end]
            end
            @testset "multi dim, sliced setindex" begin
                x = fill(AT{T}, T(0), (10, 10, 10, 10))
                y = AT{T}(undef, 5, 5, 10, 10)
                rand!(y)
                x[2:6, 2:6, :, :] = y
                x[2:6, 2:6, :, :] == y
           end

        end

        for T in (Float32, Int32)
            @testset "Indexing with $T" begin
                x = fill(zero(T), 7)
                src = AT(x)
                for i = 1:7
                    src[i] = i
                end
                @test Array(src) == T[1:7;]
                src[1:3] = T[77, 22, 11]
                @test Array(src[1:3]) == T[77, 22, 11]
                src[1] = T(0)
                src[2:end] = T(77)
                @test Array(src) == T[0, 77, 77, 77, 77, 77, 77]
            end
        end

        for T in (Float32, Int32)
            @testset "issue #42 with $T" begin
                Ac = rand(Float32, 2, 2)
                A = AT(Ac)
                @test A[1] == Ac[1]
                @test A[end] == Ac[end]
                @test A[1, 1] == Ac[1, 1]
            end
        end
        for T in (Float32, Int32)
            @testset "Colon() $T" begin
                Ac = rand(T, 10)
                A = AT(Ac)
                A[:] = T(1)
                @test all(x-> x == 1, A)
                A[:] = AT(Ac)
                @test Array(A) == Ac
            end
        end
    end
end
