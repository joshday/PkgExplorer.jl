module PkgExplorer

using Dates
using Pkg
using Pkg.Types: VersionSpec, Project, Compat, is_stdlib
using Pkg.Versions: VersionRange, VersionBound, semver_spec

using DataFrames

export ProjectCompat, registry_df, registries, pkg_entry, versions,
    update_compat, update_compat!,
    is_stdlib # re-export from Pkg.Types

#-----------------------------------------------------------------------------# __init__
const registry_df = DataFrame()

function __init__()
    for reg in registries
        Pkg.Registry.init_package_info!.(values(reg.pkgs))
        Pkg.Registry.create_name_uuid_mapping!(reg)
    end
    registry_df!()
end

#-----------------------------------------------------------------------------# registry_df!
function registry_df!(registries = Pkg.Registry.reachable_registries())
    @info "Updating registry_df..."
    for reg in registries
        Pkg.Registry.init_package_info!.(values(reg.pkgs))
        Pkg.Registry.create_name_uuid_mapping!(reg)
    end
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

versions(pkg::Union{String,Base.UUID}; include_yanked::Bool=false) = sort!(collect(keys(version_infos(pkg; include_yanked))))

#-----------------------------------------------------------------------------# update_compat
function update_compat(old_project::Project; io::IO = stdout, verbose=true, ignore=[])
    p(args...; kw...) = verbose && printstyled(io, args...; kw...)
    p("update_compat with Project: ", repr(old_project.name), ": \n", color=:light_black)
    project = deepcopy(old_project)

    for (pkg, uuid) in project.deps
        (pkg == "julia" || is_stdlib(uuid) || pkg in ignore) && continue
        (; val, str) = get(project.compat, pkg, (;val = nothing, str=""))

        all_versions = versions(uuid)
        all_majorminor = unique!(map(x -> VersionNumber(x.major, x.minor), all_versions))
        (; major, minor) = all_majorminor[end]

        if isempty(str)
            str = "$major.$minor"
        else
            latest_spec = VersionNumber(split(str, ", ")[end])
            versions_to_add = filter(x -> x > latest_spec, all_majorminor)
            for v in versions_to_add
                str *= ", $(v.major).$(v.minor)"
            end
        end

        project.compat[pkg] = Compat(semver_spec(str), str)
        old = get(old_project.compat, pkg, (;str=nothing))
        new = project.compat[pkg]
        if old != new
            p("  ", pkg, " = ", repr(old.str); color=:light_yellow)
            p(" → ", repr(new.str), "\n", color=:light_cyan)
        else
            p("  ✓ $pkg = ", repr(old.str), "\n", color=:light_green)
        end
    end
    return project
end

update_project(file::String; kw...) = update_compat(Pkg.Types.read_project(file); kw...)

update_compat!(file::String; kw...) = Pkg.Types.write_project(update_project(file; kw...), file)

end
