function Base.fill(X::Type{<: GPUArray}, val::T, dims::NTuple{N, Integer}) where {T, N}
    res = similar(X{T}, dims)
    fill!(res, val)
end
function Base.fill(X::Type{<: GPUArray{T}}, val, dims::NTuple{N, Integer}) where {T, N}
    res = similar(X, dims)
    fill!(res, convert(T, val))
end
function Base.fill!(A::GPUArray{T}, x) where T
    gpu_call(A, (A, convert(T, x))) do state, a, val
        idx = @linearidx(a, state)
        @inbounds a[idx] = val
        return
    end
    A
end

Base.zeros(T::Type{<: GPUArray}, dims::NTuple{N, Integer}) where N = fill(T, zero(eltype(T)), dims)
Base.ones(T::Type{<: GPUArray}, dims::NTuple{N, Integer}) where N = fill(T, one(eltype(T)), dims)

function uniformscaling_kernel(state, res::AbstractArray{T}, stride, s::UniformScaling) where T
    i = linear_index(state)
    i > stride && return
    ilin = (stride * (i - 1)) + i
    @inbounds res[ilin] = s.λ
    return
end

function (T::Type{<: GPUArray})(s::UniformScaling, dims::Dims{2})
    res = zeros(T, dims)
    gpu_call(uniformscaling_kernel, res, (res, size(res, 1), s), minimum(dims))
    res
end
(T::Type{<: GPUArray})(s::UniformScaling, m::Integer, n::Integer) = T(s, Dims((m, n)))

function indexstyle(x::T) where T
    style = try
        Base.IndexStyle(x)
    catch
        nothing
    end
    style
end

function collect_kernel(state, A, iter, ::IndexCartesian)
    idx = @cartesianidx(A, state)
    @inbounds A[idx...] = iter[idx...]
    return
end

function collect_kernel(state, A, iter, ::IndexLinear)
    idx = linear_index(state)
    @inbounds A[idx] = iter[idx]
    return
end

eltype_or(::Type{<: GPUArray}, or) = or
eltype_or(::Type{<: GPUArray{T}}, or) where T = T
eltype_or(::Type{<: GPUArray{T, N}}, or) where {T, N} = T

function Base.convert(AT::Type{<: GPUArray}, iter)
    isize = Base.IteratorSize(iter)
    style = indexstyle(iter)
    ettrait = Base.IteratorEltype(iter)
    if isbits(iter) && isa(isize, Base.HasShape) && style != nothing && isa(ettrait, Base.HasEltype)
        # We can collect on the GPU
        A = similar(AT, eltype_or(AT, eltype(iter)), size(iter))
        gpu_call(collect_kernel, A, (A, iter, style))
        A
    else
        convert(AT, collect(iter))
    end
end

function Base.convert(AT::Type{<: GPUArray{T, N}}, A::DenseArray{T, N}) where {T, N}
    copyto!(AT(undef, size(A)), A)
end

function Base.convert(AT::Type{<: GPUArray{T1}}, A::DenseArray{T2, N}) where {T1, T2, N}
    copyto!(similar(AT, size(A)), convert(Array{T1, N}, A))
end

function Base.convert(AT::Type{<: GPUArray}, A::DenseArray{T2, N}) where {T2, N}
    copyto!(similar(AT{T2}, size(A)), A)
end

function Base.convert(AT::Type{Array{T, N}}, A::GPUArray{CT, CN}) where {T, N, CT, CN}
    convert(AT, copyto!(Array{CT, CN}(undef, size(A)), A))
end
