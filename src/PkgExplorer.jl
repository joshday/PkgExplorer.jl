module PkgExplorer

using Pkg
using TOML
using Printf
using Dates

using DataFrames

export pkgs, stdlibs, update_compat, update_compat!

#-----------------------------------------------------------------------------# __init__
const pkgs = DataFrame()
const stdlibs = DataFrame()
registry_updated_at = now()

function __init__()
    Pkg.Registry.update()
    registry_updated_at = now()
    append!(pkgs, pkgs_df())
    append!(stdlibs, stdlibs_df())
end

#-----------------------------------------------------------------------------# get DataFrames
function pkgs_df(registries = Pkg.Registry.reachable_registries())
    df = mapreduce(vcat, registries, init = DataFrame()) do reg
        foreach(x-> Pkg.Registry.init_package_info!(x[2]), reg.pkgs)
        DataFrame((
                name = entry.name,
                uuid = entry.uuid,
                compat = entry.info.compat,
                deps = entry.info.deps,
                repo = entry.info.repo,
                subdir = entry.info.subdir,
                versions = entry.info.version_info,
                weak_compat = entry.info.weak_compat,
                weak_deps = entry.info.weak_deps,
                stdlib = entry.uuid in keys(Pkg.Types.stdlibs())
            ) for entry in values(reg.pkgs)
        )
    end
    metadata!(df, "generated_at", now(), style=:note)
    metadata!(df, "registries", registries, style=:note)
    return df
end

stdlibs_df() = DataFrame((; name = x[2][1], uuid = x[1], version=x[2][2]) for x in Pkg.Types.stdlibs())

#-----------------------------------------------------------------------------# utils
pkg_data(pkg::String) = only(pkgs[pkgs.name .== pkg, :])
pkg_data(uuid::Base.UUID) = only(pkgs[pkgs.uuid .== uuid, :])

function versions(pkg::Union{Base.UUID, String}; include_yanked=false)
    v = pkg_data(pkg).versions
    !include_yanked && filter!(x -> !x.second.yanked, v)
    sort!(collect(keys(v)))
end

#-----------------------------------------------------------------------------# update_compat
function update_compat(project_toml::String)
    data = TOML.parsefile(project_toml)
    compat = get!(data, "compat", Dict{String,Any}())
    deps = get!(data, "deps", Dict{String,Any}())
    old_data = deepcopy(data)
    df = filter(x -> x.uuid in Base.UUID.(values(deps)) && !x.stdlib, pkgs)
    for row in eachrow(df)
        pkg = row.name

        # Most recent version in registry (that hasn't been yanked):
        (; major, minor, patch)  = maximum(versions(pkg))
        upper = "$major.$minor"

        if haskey(compat, pkg) && compat[pkg] != upper
            compat_entry = compat[pkg]
            if any(x -> occursin(x, compat_entry), "=~^,")
                @warn "Only hyphen-specifiers are supported.  Found: $compat_entry."
                continue
            end
            lower = split(compat_entry, " - ")[1]
            compat[pkg] = lower == upper ? lower : "$lower - $upper"
        else
            data["compat"][pkg] = upper
        end
    end

    for (k,v) in data["compat"]
        old = get(old_data["compat"], k, "")
        if old != v
            printstyled("$k: "; color=:light_cyan)
            printstyled(old, "  ", color=:light_black)
            printstyled(string(v), '\n'; color=:green, underline=true, bold=true)
        end
    end

    return data
end

function update_compat!(project_toml::String)
    original = read(project_toml, String)
    try
        data = update_compat(project_toml)
        get!(data, "compat", Dict{String,Any}())
        io = IOBuffer()
        TOML.print(io, data; sorted=true, by=key->(Pkg.Types.project_key_order(key), key))
        content = String(take!(io))

        compat = filter(kv -> kv[1] != "julia", data["compat"])
        lines = Dict(k => string(k, " = ", repr(v)) for (k,v) in compat)

        width = maximum(length, values(lines))
        content = replace(content, "[compat]" => "[compat]" * ' ' ^ (width - 6) * "# Latest:")
        for (pkg, line) in lines
            v = maximum(versions(pkg))
            content = replace(content, line => line * ' ' ^ (width - length(line)) * "  #   $v")
        end

        open(project_toml, "w") do io
            println(io, "# Updated by PkgExplorer.jl at ", Dates.format(now(UTC), "yyyy-mm-dd HH:MM:SS"), " (UTC).")
            print(io, content)
        end
        return project_toml
    catch
        @warn "An Error occurred.  Restoring original file: $project_toml."
        open(project_toml, "w") do io
            print(io, original)
        end
    end
end

end
