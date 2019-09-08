
# Interface that needs to be overwritten by backend
# Slightly difference behavior from buffer, since not all blas backends work directly with
# the gpu array buffer
function blas_module(A)
    error("$(typeof(A)) doesn't support BLAS operations")
end
function blasbuffer(A)
    error("$(typeof(A)) doesn't support BLAS operations")
end

for elty in (Float32, Float64, ComplexF32, ComplexF64)
    T = VERSION >= v"1.3.0-alpha.115" ? :(Union{($elty), Bool}) : elty
    @eval begin
        function BLAS.gemm!(
                transA::AbstractChar, transB::AbstractChar, alpha::$T,
                A::GPUVecOrMat{$elty}, B::GPUVecOrMat{$elty},
                beta::$T, C::GPUVecOrMat{$elty}
            )
            blasmod = blas_module(A)
            result = blasmod.gemm!(
                transA, transB, alpha,
                blasbuffer(A), blasbuffer(B), beta, blasbuffer(C)
            )
            C
        end
    end
end

for elty in (Float64, Float32)
    @eval begin
        function BLAS.scal!(
                n::Integer, DA::$elty,
                DX::GPUArray{$elty, N}, incx::Integer
            ) where N
            blasmod = blas_module(DX)
            blasmod.scal!(n, DA, blasbuffer(DX), incx)
            DX
        end
    end
end

LinearAlgebra.rmul!(s::Number, X::GPUArray) = rmul!(X, s)
function LinearAlgebra.rmul!(X::GPUArray{T}, s::Number) where T <: BLAS.BlasComplex
    R = typeof(real(zero(T)))
    N = 2*length(X)
    buff = unsafe_reinterpret(R, X, (N,))
    BLAS.scal!(N, R(s), buff, 1)
    X
end
function LinearAlgebra.rmul!(X::GPUArray{T}, s::Number) where T <: Union{Float32, Float64}
    BLAS.scal!(length(X), T(s), X, 1)
    X
end


for elty in (Float32, Float64, ComplexF32, ComplexF64)
    T = VERSION >= v"1.3.0-alpha.115" ? :(Union{($elty), Bool}) : elty
    @eval begin
        function BLAS.gemv!(trans::AbstractChar, alpha::$T, A::GPUVecOrMat{$elty}, X::GPUVector{$elty}, beta::$T, Y::GPUVector{$elty})
            m, n = size(A, 1), size(A, 2)
            if trans == 'N' && (length(X) != n || length(Y) != m)
                throw(DimensionMismatch("A has dimensions $(size(A)), X has length $(length(X)) and Y has length $(length(Y))"))
            elseif trans == 'C' && (length(X) != m || length(Y) != n)
                throw(DimensionMismatch("A' has dimensions $n, $m, X has length $(length(X)) and Y has length $(length(Y))"))
            elseif trans == 'T' && (length(X) != m || length(Y) != n)
                throw(DimensionMismatch("A.' has dimensions $n, $m, X has length $(length(X)) and Y has length $(length(Y))"))
            end
            blasmod = blas_module(A)
            blasmod.gemv!(
                trans, alpha,
                blasbuffer(A), blasbuffer(X), beta, blasbuffer(Y)
            )
            Y
        end
    end
end


for elty in (Float32, Float64, ComplexF32, ComplexF64)
    @eval begin
        function BLAS.axpy!(
                alpha::Number, x::GPUArray{$elty}, y::GPUArray{$elty}
            )
            if length(x) != length(y)
                throw(DimensionMismatch("x has length $(length(x)), but y has length $(length(y))"))
            end
            blasmod = blas_module(x)
            blasmod.axpy!($elty(alpha), blasbuffer(vec(x)), blasbuffer(vec(y)))
            y
        end
    end
end


for elty in (Float32, Float64, ComplexF32, ComplexF64)
    @eval begin
        function BLAS.gbmv!(trans::AbstractChar, m::Integer, kl::Integer, ku::Integer, alpha::($elty), A::GPUMatrix{$elty}, X::GPUVector{$elty}, beta::($elty), Y::GPUVector{$elty})
            n = size(A, 2)
            if trans == 'N' && (length(X) != n || length(Y) != m)
                throw(DimensionMismatch("A has dimensions $n, $m, X has length $(length(X)) and Y has length $(length(Y))"))
            elseif trans == 'C' && (length(X) != m || length(Y) != n)
                throw(DimensionMismatch("A' has dimensions $n, $m, X has length $(length(X)) and Y has length $(length(Y))"))
            elseif trans == 'T' && (length(X) != m || length(Y) != n)
                throw(DimensionMismatch("A.' has dimensions $n, $m, X has length $(length(X)) and Y has length $(length(Y))"))
            end
            blasmod = blas_module(A)
            blasmod.gbmv!(
                trans, m, kl, ku, alpha,
                blasbuffer(A), blasbuffer(X), beta, blasbuffer(Y)
            )
            Y
        end
    end
end
