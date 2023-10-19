using Statistics

"""
Extract Neighborhood Composition Vectors (NCVs) from a dataset

# Args

- `coordinates`:            CSV file with coordinates of molecules and gene type

# Options

- `-k, --k-neighbors=<k>`:              Number of neighbors for segmentation-free pseudo-cells. It's suggested to set it to the expected minimal number of molecules per cell. (default: inferred from `min-molecules-per-cell`)
- `-n, --ncvs-to-save=<n>`:             Number of NCVs to save. If set, selects NCVs uniformly across the first 2 PCs. (default: 0, all of them)

- `-c, --config=<config.toml>`:         TOML file with a config. The function only uses the `[data]` section.
- `-x, --x-column=<x>`:                 Name of x column. Overrides the config value.
- `-y, --y-column=<y>`:                 Name of y column. Overrides the config value.
- `-z, --z-column=<z>`:                 Name of z column. Overrides the config value.
- `-g, --gene-column=<gene>`:           Name of gene column. Overrides the config value.
- `-m, --min-molecules-per-cell=<m>`:   Minimal number of molecules for a cell to be considered as real.
                                        It's an important parameter, as it's used to infer several other parameters.
                                        Overrides the config value.
- `-o, --output=<path>`:                Name of the output file or path to the output directory (default: "ncvs.loom")
- `--ncv-method=<method>`:               Method for PCA estimation for NCV dimensionality reduction. Possible values: `dense`, `sparse`, `auto`.
                                        `dense` method can provide better results, but takes much more memory.
                                        (default: `auto`, i.e. `dense` for small datasets and `sparse` for large ones)
"""
@cast function segfree(
        coordinates::String;
        config::RunOptions=RunOptions(),
        k_neighbors::Int=0,
        # ncvs_to_save::Int=0, # TODO: uncomment and use it in the code
        x_column::String=config.data.x, y_column::String=config.data.y, z_column::String=config.data.z,
        gene_column::String=config.data.gene, min_molecules_per_cell::Int=config.data.min_molecules_per_cell,
        output::String="ncvs.loom", ncv_method::Symbol=:auto
    )
    opts = config.data;
    opts = from_dict(DataOptions,
        merge(to_dict(opts), Dict(
            "x" => x_column, "y" => y_column, "z" => z_column, "gene" => gene_column,
            "min_molecules_per_cell" => min_molecules_per_cell
        ))
    )

    fill_and_check_options!(opts)
    if isdir(output) || isdirpath(output)
        output = joinpath(output, "ncvs.loom")
    end

    Random.seed!(1)
    log_file = setup_logger(output, "segfree_log.log")

    run_id = get_run_id()
    @info "Run $run_id"
    @info "# CLI params: `$(join(ARGS[2:end], " "))`"
    @info get_baysor_run_str()

    # Run NCV estimates

    @info "Loading data..."
    df_spatial, gene_names = DAT.load_df(coordinates, opts)

    if k_neighbors == 0
        (opts.min_molecules_per_cell > 0) || cmd_error("Either `min-molecules-per-cell` or `k` must be provided")
        k_neighbors = default_param_value(:composition_neighborhood, opts.min_molecules_per_cell, n_genes=length(gene_names))
    end

    @info "Estimating neighborhoods..."
    neighb_cm = BPR.neighborhood_count_matrix(df_spatial, k_neighbors);

    @info "Estimating molecule confidences..."
    confidences = BPR.estimate_confidence(df_spatial, nn_id=opts.confidence_nn_id)[2]

    @info "Estimating gene colors..."

    pca = BPR.gene_pca(neighb_cm, 20; method=ncv_method)[1]
    col_emb = BPR.gene_composition_color_embedding(pca, confidences)
    gene_colors = BPR.embedding_to_hex(col_emb)

    @info "Saving results..."
    DAT.save_matrix_to_loom(
        neighb_cm'; gene_names=gene_names, cell_names=get_cell_name.(1:size(neighb_cm, 2); type=:ncv, run_id),
        col_attrs=Dict("ncv_color" => gene_colors, "confidence" => confidences), file_path=output
    )

    @info "Done!"
    close(log_file)

    return 0
end
