using PkgExplorer
using PkgExplorer.ProjectCompat
using DataFrames
using Test


@test nrow(registry_df) ≥ 9603 # (count of packages as of 2023-07-03)

#-----------------------------------------------------------------------------# update_compat!
@testset "update_compat!" begin
    file = cp(joinpath(@__DIR__, "example.toml"), tempname(); force=true)

    e = read_compat_entries(file)

    e2 = update.(e)

    @test all(map(!ProjectCompat.is_outdated, e2))
end
