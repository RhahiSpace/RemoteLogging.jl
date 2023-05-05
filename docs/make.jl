using RemoteLogging
using Documenter

DocMeta.setdocmeta!(RemoteLogging, :DocTestSetup, :(using RemoteLogging); recursive=true)

makedocs(;
    modules=[RemoteLogging],
    authors="Rhahi <git@rhahi.com> and contributors",
    repo="https://github.com/rhahi/RemoteLogging.jl/blob/{commit}{path}#{line}",
    sitename="RemoteLogging.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://rhahi.github.io/RemoteLogging.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/rhahi/RemoteLogging.jl",
    devbranch="main",
)
