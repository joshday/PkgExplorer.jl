using PkgExplorer
using DataFrames
using Test


@test nrow(pkgs) ≥ 9603 # (count of packages as of 2023-07-03)

#-----------------------------------------------------------------------------# update_compat!
@testset "update_compat!" begin
    file = cp(joinpath(@__DIR__, "example.toml"), tempname(); force=true)

    a = read(file, String)

    @test_warn "Only hyphen" update_compat!(file)

    b = read(file, String)

    @test a != b

    v = maximum(PkgExplorer.versions("StatsFuns"))
    line = "StatsFuns = \"1.0 - $(v.major).$(v.minor)\""

    @test !occursin(line, a)
    @test occursin(line, b)
end
