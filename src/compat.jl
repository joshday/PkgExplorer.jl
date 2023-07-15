#-----------------------------------------------------------------------------# update_compat
# deps::Dict{String, Base.UUID}
# compat::Dict{String, Pkg.Types.Compat}

function update_compat(project::Pkg.Types.Project)
    for (pkg, compat) in project.compat
        is_stdlib(pkg) || pkg == "julia" && continue
        (;val, str) = compat
        available_versions = versions(pkg)
        latest = maximum(available_versions)
        if latest ∈ available_versions
            @info "$pkg is up-to-date. $latest ∈ $(repr(str))"
        else
            @info "`$pkg = $(repr(str))` is out-of-date.  Latest version: $latest"
        end
    end
end


#-----------------------------------------------------------------------------# update_compat_entry
# e.g. entry = `EasyConfig = "0.1.15"`
function update_compat_entry(entry::String)
    pkg, bounds = replace.(strip.(split(entry, '=')), Ref('"' => ""))
    available_versions = versions(pkg)
end



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
