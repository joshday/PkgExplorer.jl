module PkgExplorer

using Dates
using Pkg
using Pkg.Types: VersionSpec, Project, Compat, is_stdlib
using Pkg.Versions: VersionRange, VersionBound, semver_spec

using DataFrames

function __init__()
    registry_df!()
end

#-----------------------------------------------------------------------------# globals
registry_df::DataFrame = DataFrame()

registries::Vector{Pkg.Registry.RegistryInstance} = Pkg.Registry.reachable_registries()

#-----------------------------------------------------------------------------# registry_df!
function registry_df!()
    for reg in registries
        @info "Updating `registry_df` for registry: $(reg.name)"
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
    global registry_df = temp_df
end

#-----------------------------------------------------------------------------# getters
uuid(x::Base.UUID) = x
uuid(x::AbstractString) = registry_df.uuid[only(findall(x .== registry_df.name))]

function entry(x)
    pkg = uuid(x)
    for reg in registries
        haskey(reg.pkgs, pkg) && return reg.pkgs[pkg]
    end
end


name(x) = entry(x).name
info(x) = entry(x).info
repo(x) = info(x).repo

function version_infos(x; include_yanked::Bool=false)
    info = entry(x).info.version_info
    !include_yanked ? filter(x -> !x.second.yanked, info) : info
end
versions(x; include_yanked::Bool=false) = sort!(collect(keys(version_infos(x; include_yanked))))

function deps(x, v::VersionNumber = maximum(versions(x)))
    (;
        deps = reduce(merge, values(filter(x -> v in x[1], info(x).deps)); init=Dict{Pkg.Versions.VersionRange, Dict{String, Base.UUID}}()),
        compat = reduce(merge, values(filter(x -> v in x[1], info(x).compat)); init=Dict{Pkg.Versions.VersionRange, Dict{String, Base.UUID}}()),
        weak_deps = reduce(merge, values(filter(x -> v in x[1], info(x).weak_deps)); init=Dict{Pkg.Versions.VersionRange, Dict{String, Base.UUID}}()),
        weak_compat = reduce(merge, values(filter(x -> v in x[1], info(x).weak_compat)); init=Dict{Pkg.Versions.VersionRange, Dict{String, Base.UUID}}())
    )
end



# #-----------------------------------------------------------------------------# update_compat
# function update_compat(old_project::Project; io::IO = stdout, verbose=true, ignore=[])
#     p(args...; kw...) = verbose && printstyled(io, args...; kw...)
#     p("update_compat with Project: ", repr(old_project.name), ": \n", color=:light_black)
#     project = deepcopy(old_project)

#     for (pkg, uuid) in project.deps
#         (pkg == "julia" || is_stdlib(uuid) || pkg in ignore) && continue
#         (; val, str) = get(project.compat, pkg, (;val = nothing, str=""))

#         all_versions = versions(uuid)
#         all_majorminor = unique!(map(x -> VersionNumber(x.major, x.minor), all_versions))
#         (; major, minor) = all_majorminor[end]

#         if isempty(str)
#             str = "$major.$minor"
#         else
#             latest_spec = VersionNumber(split(str, ", ")[end])
#             versions_to_add = filter(x -> x > latest_spec, all_majorminor)
#             for v in versions_to_add
#                 str *= ", $(v.major).$(v.minor)"
#             end
#         end

#         project.compat[pkg] = Compat(semver_spec(str), str)
#         old = get(old_project.compat, pkg, (;str=nothing))
#         new = project.compat[pkg]
#         if old != new
#             p("  ", pkg, " = ", repr(old.str); color=:light_yellow)
#             p(" → ", repr(new.str), "\n", color=:light_cyan)
#         else
#             p("  ✓ $pkg = ", repr(old.str), "\n", color=:light_green)
#         end
#     end
#     return project
# end

# update_project(file::String; kw...) = update_compat(Pkg.Types.read_project(file); kw...)

# update_compat!(file::String; kw...) = Pkg.Types.write_project(update_project(file; kw...), file)

# #-----------------------------------------------------------------------------# test

# # scenario = :update_compat | :ignore_compat | :oldest_in_compat
# function test(pkg::Base.UUID, scenario::Symbol)
# end

end  # module
