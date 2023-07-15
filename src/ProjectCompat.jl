module ProjectCompat

using ..PkgExplorer: pkg_entry, versions
using Pkg.Types: VersionSpec, Project, read_project, is_stdlib
using Pkg.Versions: VersionRange, VersionBound

export VersionSpec, Project, read_project, is_stdlib, VersionRange, VersionBound,
    CompatEntry, update, read_compat_entries

#-----------------------------------------------------------------------------# CompatEntry
mutable struct CompatEntry
    project::Project
    pkg::String
    uuid::Base.UUID
    val::Union{Nothing, VersionSpec}
    str::Union{Nothing, String}
end

function CompatEntry(project::Project, pkg::String)
    uuid = pkg_entry(pkg).uuid
    (;val, str) = get(project.compat, pkg, (;val=nothing, str=nothing))
    CompatEntry(project, pkg, uuid, val, str)
end

function Base.show(io::IO, entry::CompatEntry)
    (; project, pkg, uuid, val, str) = entry
    p(args...; kw...) = printstyled(io, args...; kw...)
    p("CompatEntry"; color=:normal)
    p(" ", project.name, ": ", color=:light_black)
    if isnothing(val)
        p(pkg, " = (missing)"; color=:light_red)
    else
        p(pkg, " = ", repr(str); color=:light_cyan)
        latest = maximum(versions(uuid))
        latest in val ?
            p(" ($latest ∈ $val)"; color=:light_green) :
            p(" ($latest ∉ $val)"; color=:light_red)
    end
end

function read_compat_entries(project_toml::String)
    project = read_project(project_toml)
    CompatEntry.(Ref(project), keys(filter(x -> !is_stdlib(x[2]), project.deps)))
end


is_outdated(x::CompatEntry) = isnothing(x.val) ? true : maximum(versions(x.uuid)) ∉ x.val

#-----------------------------------------------------------------------------# update
# TODO: Work with un-registered dependencies
function update(entry::CompatEntry)
    (; project, pkg, uuid, val, str) = entry
    vrs = versions(uuid)
    latest = maximum(vrs)
    (; major, minor) = latest
    if isnothing(val)
        spec = VersionSpec("$major.$minor")
        return CompatEntry(project, pkg, uuid, spec, string(spec))
    elseif latest ∈ val
        return entry
    else
        max_range = maximum(val.ranges)
        entry = deepcopy(entry)
        upper = VersionBound((major, minor))
        push!(entry.val.ranges, VersionRange(max_range.upper, upper))
        union!(entry.val.ranges)
        entry.str = string(entry.val)
        return entry
    end
end

# x = read_compat_entries("/Users/joshday/.julia/dev/OnlineStats/Project.toml")
# entry = x[end]


end #module

# #-----------------------------------------------------------------------------# update_compat
# function update_compat(project_toml::String)
#     data = TOML.parsefile(project_toml)
#     compat = get!(data, "compat", Dict{String,Any}())
#     deps = get!(data, "deps", Dict{String,Any}())
#     old_data = deepcopy(data)
#     df = filter(x -> x.uuid in Base.UUID.(values(deps)) && !x.stdlib, pkgs)
#     for row in eachrow(df)
#         pkg = row.name

#         # Most recent version in registry (that hasn't been yanked):
#         (; major, minor, patch)  = maximum(versions(pkg))
#         upper = "$major.$minor"

#         if haskey(compat, pkg) && compat[pkg] != upper
#             compat_entry = compat[pkg]
#             if any(x -> occursin(x, compat_entry), "=~^,")
#                 @warn "Only hyphen-specifiers are supported.  Found: $compat_entry."
#                 continue
#             end
#             lower = split(compat_entry, " - ")[1]
#             compat[pkg] = lower == upper ? lower : "$lower - $upper"
#         else
#             data["compat"][pkg] = upper
#         end
#     end

#     for (k,v) in data["compat"]
#         old = get(old_data["compat"], k, "")
#         if old != v
#             printstyled("$k: "; color=:light_cyan)
#             printstyled(old, "  ", color=:light_black)
#             printstyled(string(v), '\n'; color=:green, underline=true, bold=true)
#         end
#     end

#     return data
# end

# function update_compat!(project_toml::String)
#     original = read(project_toml, String)
#     try
#         data = update_compat(project_toml)
#         get!(data, "compat", Dict{String,Any}())
#         io = IOBuffer()
#         TOML.print(io, data; sorted=true, by=key->(Pkg.Types.project_key_order(key), key))
#         content = String(take!(io))

#         compat = filter(kv -> kv[1] != "julia", data["compat"])
#         lines = Dict(k => string(k, " = ", repr(v)) for (k,v) in compat)

#         width = maximum(length, values(lines))
#         content = replace(content, "[compat]" => "[compat]" * ' ' ^ (width - 6) * "# Latest:")
#         for (pkg, line) in lines
#             v = maximum(versions(pkg))
#             content = replace(content, line => line * ' ' ^ (width - length(line)) * "  #   $v")
#         end

#         open(project_toml, "w") do io
#             print(io, content)
#         end
#         return project_toml
#     catch
#         @warn "An Error occurred.  Restoring original file: $project_toml."
#         open(project_toml, "w") do io
#             print(io, original)
#         end
#     end
# end
