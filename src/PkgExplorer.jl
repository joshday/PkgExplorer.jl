module PkgExplorer


using Pkg
using TOML
using Printf
using Dates

using DataFrames

export registry_df, update_compat, update_compat!

#-----------------------------------------------------------------------------# registry_df
function registry_df()
    df = mapreduce(vcat, Pkg.Registry.reachable_registries(), init = DataFrame()) do reg
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
                stdlib = uuid in keys(Pkg.Types.stdlibs())
            ) for (uuid,entry) in reg.pkgs
        )
    end
    stdlibs = DataFrame((; name = x[2][1], uuid = x[1], stdlib_version=x[2][2], stdlib=true) for x in Pkg.Types.stdlibs())
    out = outerjoin(df, stdlibs, on = [:uuid, :name, :stdlib])
    nrow(out) == length(unique(out.uuid)) || @warn "Duplicate UUIDs found in registry!"
    metadata!(out, "generated_at", now(), style=:note)
    return out
end

#-----------------------------------------------------------------------------# update_compat
function update_compat(project_toml::String)
    endswith(project_toml, "Project.toml") ||
        error("Expected basename of `Project.toml` or `JuliaProject.toml`.  Found: `$(basename(project_toml))`.")
    isfile(project_toml) || error("File not found: $project_toml")
    data = TOML.parsefile(project_toml)
    compat = get!(data, "compat", Dict{String,Any}())
    deps = get!(data, "deps", Dict{String,Any}())
    old_data = deepcopy(data)
    df = filter(x -> x.uuid in Base.UUID.(values(deps)), registry_df())
    for row in eachrow(df)
        pkg = row.name
        row.uuid in keys(Pkg.Types.stdlibs()) && continue

        # Most recent version in registry (that hasn't been yanked):
        most_recent_version = maximum(first.(filter(x -> !x[2].yanked, collect(row.versions))))
        (major, minor) = (most_recent_version.major, most_recent_version.minor)
        upper = "$major.$minor"

        if haskey(compat, pkg)
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
    data = update_compat(project_toml)
    open(project_toml, "w") do io
        TOML.print(io, data; sorted=true, by=key->(Pkg.Types.project_key_order(key), key))
    end
end

end
