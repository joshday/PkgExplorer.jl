module PkgExplorer

using Dates
using Pkg
using Pkg.Types: VersionSpec, Project, read_project, is_stdlib

using DataFrames

export ProjectCompat, registry_df, pkg_entry, versions

#-----------------------------------------------------------------------------# __init__
const registries = Pkg.Registry.reachable_registries()
const registry_df = DataFrame()

function __init__()
    @info "Updating Registries..."
    Pkg.Registry.update()
    for reg in registries
        Pkg.Registry.init_package_info!.(values(reg.pkgs))
        Pkg.Registry.create_name_uuid_mapping!(reg)
    end
    @info "Updating `registry_df`..."
    temp_df = mapreduce(vcat, registries, init = DataFrame()) do reg
        DataFrame((
                registry = reg.name,
                name = entry.name,
                uuid = entry.uuid,
                compat = entry.info.compat,
                deps = entry.info.deps,
                repo = entry.info.repo,
                subdir = entry.info.subdir,
                versions = entry.info.version_info,
                weak_compat = entry.info.weak_compat,
                weak_deps = entry.info.weak_deps,
                stdlib = is_stdlib(entry.uuid)
            ) for entry in values(reg.pkgs)
        )
    end
    metadata!(temp_df, "generated_at", now(), style=:note)
    metadata!(temp_df, "registries", registries, style=:note)
    append!(registry_df, temp_df)
end

#-----------------------------------------------------------------------------# pkg_entry
function pkg_entry(pkg::Base.UUID)
    for reg in registries
        haskey(reg.pkgs, pkg) && return reg.pkgs[pkg]
    end
end
function pkg_entry(pkg::String)
    for reg in registries
        if haskey(reg.name_to_uuids, pkg)
            entries = reg.name_to_uuids[pkg]
            length(entries) > 1 && @warn "Multiple entries found for $pkg.  Returning first entry."
            return pkg_entry(entries[1])
        end
    end
end

#-----------------------------------------------------------------------------# versions
function version_infos(pkg::Union{String,Base.UUID}; include_yanked::Bool=false)
    info = pkg_entry(pkg).info.version_info
    !include_yanked ? filter(x -> !x.second.yanked, info) : info
end

versions(pkg::Union{String,Base.UUID}; include_yanked::Bool=false) = collect(keys(version_infos(pkg; include_yanked)))

#-----------------------------------------------------------------------------# Compat
include("ProjectCompat.jl")



# function update_compat(project_toml::String; io=stdout)
#     project = read_project(file)
#     df = DataFrame(
#         pkg = String[],
#         versions = VersionNumber[],
#         compat_val = VersionSpec[],
#         compat_str = String[],
#         latest_in_compat = Bool[],

#     )

#     for (pkg, compat) in project.compat
#         (pkg == "julia" || is_stdlib(project.deps[pkg])) && continue
#         (;val::VersionSpec, str::String) = compat
#         latest = maximum(versions(pkg))


#         # START HERE

#         red_update = latest ∈ val
#         yel_update =

#         needs_update = latest ∉ val
#         needs_update ? printstyled(io, '✗'; color=:light_red) : printstyled(io, '✔' ; color=:light_green)
#         printstyled(io, " $pkg = ", repr(str); color=:light_cyan)
#         needs_update ? printstyled(io, " ($latest)"; color=:light_red) : printstyled(io, " ($latest)"; color=:light_green)
#         println(io)
#     end
# end

end
