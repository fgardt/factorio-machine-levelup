---@class BucketsHandler<T>
---@field buckets [T[]]
---@field bucket_count uint
---@field next_bucket uint
---@field next_inserted_bucket uint

local lib = {}

---@generic T
---@param bucket_count uint
---@return BucketsHandler<T>
function lib.new(bucket_count)
    local buckets = {}
    for i = 1, bucket_count do
        buckets[i] = {}
    end

    return {
        buckets = buckets,
        bucket_count = bucket_count,
        next_bucket = 1,
        next_inserted_bucket = 1
    }
end

---@generic T
---@param handler BucketsHandler<T>
---@return T[]
function lib.get_bucket(handler)
    local bucket = handler.buckets[handler.next_bucket]
    handler.next_bucket = (handler.next_bucket % handler.bucket_count) + 1

    return bucket
end

---@generic T
---@param handler BucketsHandler<T>
---@param filter fun(item: T): boolean returns true if the item should be kept in the bucket
function lib.filter_bucket(handler, filter)
    local bucket = lib.get_bucket(handler)
    local remove = {}
    for idx, item in pairs(bucket) do
        if not filter(item) then
            table.insert(remove, idx)
        end
    end

    table.sort(remove, function(a, b) return a > b end)

    for _, idx in pairs(remove) do
        table.remove(bucket, idx)
    end
end

---@generic T
---@param handler BucketsHandler<T>
---@param item T
function lib.insert(handler, item)
    local bucket = handler.buckets[handler.next_inserted_bucket]
    table.insert(bucket, item)
    handler.next_inserted_bucket = (handler.next_inserted_bucket % handler.bucket_count) + 1
end

---@generic T
---@param handler BucketsHandler<T>
function lib.rebalance(handler)
    local count = 0
    for _, bucket in pairs(handler.buckets) do
        count = count + table_size(bucket)
    end

    local max_per_bucket = math.ceil(count / handler.bucket_count)
    local to_rebalance = {}
    for _, bucket in pairs(handler.buckets) do
        local excess = table_size(bucket) - max_per_bucket
        if excess <= 0 then goto continue end

        for _ = 1, excess do
            table.insert(to_rebalance, table.remove(bucket))
        end

        ::continue::
    end

    for _, item in pairs(to_rebalance) do
        lib.insert(handler, item)
    end
end

return lib
