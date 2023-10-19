import StatsBase

## Internals

function match_gene_names(gene_masks::Vector{String}, gene_names::Vector{String})
    matches = Set{String}()
    missing_genes = String[]
    for gm in gene_masks
        g_ids = findall(match.(Regex(gm), gene_names) .!== nothing)
        if length(g_ids) == 0
            push!(missing_genes, gm)
        else
            union!(matches, gene_names[g_ids])
        end
    end

    (length(missing_genes) == 0) || @warn "Genes $(join(missing_genes, ',')) are missing from the data"
    return matches
end

function encode_genes(genes::Vector)
    gene_names = sort(unique(skipmissing(genes)));
    gene_ids = Dict(zip(gene_names, 1:length(gene_names)))
    return [(ismissing(g) ? missing : gene_ids[g]) for g in genes], gene_names
end

function read_spatial_df(
        data_path::String; x_col::Symbol=:x, y_col::Symbol=:y, z_col::Symbol=:z,
        gene_col::Symbol=:gene, filter_cols::Bool=false, drop_z::Bool=false
    )
    # threaded code produces SentinelVector in some cases, which causes type failures later
    df_spatial = CSV.read(data_path, DataFrame, ntasks=1);


    for (cn, co) in zip((:x, :y, :z, :gene), (x_col, y_col, z_col, gene_col))
        if (co === nothing) || ((co == :z) && !(co in propertynames(df_spatial)))
            continue
        end

        if !(co in propertynames(df_spatial))
            error("$cn column '$(co)' not found in the data frame")
        end

        if (cn in propertynames(df_spatial)) & (cn != co)
            cr = Symbol(String(cn) * "_reserved")
            if cr in propertynames(df_spatial)
                DataFrames.select!(df_spatial, DataFrames.Not(cr))
            end
            DataFrames.rename!(df_spatial, cn => cr);
        end

        DataFrames.rename!(df_spatial, co => cn);
    end

    if filter_cols
        df_spatial = df_spatial[:, [:x, :y, :gene]]
    end
    df_spatial[!, :gene] = String["$g" for g in df_spatial.gene]

    if (:z in propertynames(df_spatial)) && (drop_z || (length(unique(df_spatial.z)) < 2))
        DataFrames.select!(df_spatial, DataFrames.Not(:z))
    end

    return df_spatial
end

## Exports

function load_df(data_path::String; min_molecules_per_gene::Int=0, exclude_genes::Vector{String}=String[], kwargs...)
    df_spatial = read_spatial_df(data_path; kwargs...)

    gene_counts = StatsBase.countmap(df_spatial[!, :gene]);
    large_genes = Set{String}(collect(keys(gene_counts))[collect(values(gene_counts)) .>= min_molecules_per_gene]);
    df_spatial = df_spatial[in.(df_spatial.gene, Ref(large_genes)),:];

    if length(exclude_genes) > 0
        exclude_genes = match_gene_names(exclude_genes, unique(df_spatial.gene))
        df_spatial = df_spatial[.!in.(df_spatial.gene, Ref(exclude_genes)),:];
        @info "Excluding genes: " * join(sort(collect(exclude_genes)), ", ")
    end

    for c in [:x, :y, :z]
        if c in propertynames(df_spatial)
            df_spatial[!, c] = convert(Vector{Float64}, df_spatial[!, c])
        end
    end

    df_spatial[!, :gene], gene_names = encode_genes(df_spatial[!, :gene]);
    df_spatial[!, :molecule_id] = 1:size(df_spatial, 1)

    return df_spatial, String.(gene_names);
end
