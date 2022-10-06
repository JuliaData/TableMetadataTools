module TableMetadataTools

using DataAPI
using Tables
using TOML

export label, label!
export meta2toml, toml2meta!

"""
    label(table, column)

Return string representation of the value of the `"label"` column-level metadata
of column `column` in `table` that must be compatible with Tables.jl table
interface.

If `"label"` column-level metadata for column `column` is missing return
name of column `column` as string.

# Examples

```
using TableMetadataTools
using DataFrames
using Plots
df = DataFrame(ctry=["Poland", "Canada"], gdp=[41685, 57812])
label!(df, :ctry, "Country")
label!(df, :gdp, "GDP per capita (USD PPP, 2022)")
show(df, header=label.(Ref(df), 1:nrow(df)))
bar(df.ctry, df.gdp, xlabel=label(df, :ctry), ylabel=label(df, :gdp), legend=false)
```
"""
function label(table, column)
    idx = column isa Union{Signed, Unsigned} ? Int(column) : Tables.columnindex(table, column)
    idx == 0 && throw(ArgumentError("column $col not found in table"))
    # use conditional to avoid calling Tables.columnnames if it is not needed
    if "label" in DataAPI.colmetadatakeys(table, column)
        return string(DataAPI.colmetadata(table, column, "label"))
    else
        cols = Tables.columns(table)
        return string(Tables.columnnames(cols)[idx])
    end
end

"""
    label!(table, column, label)

Store string representation of `label` as value of `"label"` key with
`:note`-style as column-level metadata for column `column` in
`table` that must be compatible with Tables.jl table interface.

# Examples

```
using TableMetadataTools
using DataFrames
using Plots
df = DataFrame(ctry=["Poland", "Canada"], gdp=[41685, 57812])
label!(df, :ctry, "Country")
label!(df, :gdp, "GDP per capita (USD PPP, 2022)")
show(df, header=label.(Ref(df), 1:nrow(df)))
bar(df.ctry, df.gdp, xlabel=label(df, :ctry), ylabel=label(df, :gdp), legend=false)
```
"""
label!(table, column, label) =
    DataAPI.colmetadata!(table, column, "label", string(label), style=:note)


"""
    meta2toml(table)

Store table-level and column-level metadata of `table` in a string using TOML.
All non-standard values stored in the metadata are converted using `string`.

# Examples

```
using TableMetadataTools
using DataFrames
df = DataFrame(ctry=["Poland", "Canada"], gdp=[41685, 57812])
label!(df, :ctry, "Country")
label!(df, :gdp, "GDP per capita (USD PPP, 2022)")
metadata!(df, "title", "GDP per country", style=:note)
metastr = meta2toml(df)
print(metastr)
df2 = DataFrame()
df2.ctry = df.ctry
df2.gdp = df.gdp
metadatakeys(df2)
colmetadatakeys(df2)
toml2meta!(metastr, df2)
println(meta2toml(df2))
```
"""
function meta2toml(table)
    allmeta = Dict{String, Dict{String}}("metadata" => Dict{String, Any}(),
                                         "colmetadata" => Dict{String, Any}())
    for metakey in metadatakeys(table)
        value, style = metadata(table, metakey, style=true)
        allmeta["metadata"][metakey] = Dict{String, Any}("value" => value, "style" => string(style))
    end

    for (col, colmetakeys) in colmetadatakeys(table)
        colmetadict = Dict{String, Any}()
        for colmetakey in colmetakeys
            value, style = colmetadata(table, col, colmetakey, style=true)
            colmetadict[colmetakey] = Dict{String, Any}("value" => value, "style" => string(style))
        end
        allmeta["colmetadata"][string(col)] = colmetadict
    end

    io = IOBuffer()
    TOML.print(string, io, allmeta, sorted=true)
    return String(take!(io))
end

"""
    toml2meta!(tomlstr, table)

Store table-level and column-level metadata represented in TOML and passed
in `tomlstr` string to `table` (discarding all previously present metadata).

The funcion assumes that `tomlstr` is a properly formatted TOML, preferably
previously generated by [meta2toml](@ref).
"""
function toml2meta!(tomlstr, table)
    allmeta = TOML.parse(tomlstr)
    DataAPI.emptymetadata!(table)
    DataAPI.emptycolmetadata!(table)

    for (metakey, vs_dict) in pairs(allmeta["metadata"])
        value = vs_dict["value"]
        style = vs_dict["style"]
        metadata!(table, metakey, value, style=Symbol(style))
    end

    for col in keys(allmeta["colmetadata"])
        for (colmetakey, vs_dict) in pairs(allmeta["colmetadata"][col])
            value = vs_dict["value"]
            style = vs_dict["style"]
            colmetadata!(table, Symbol(col), colmetakey, value, style=Symbol(style))
        end
    end

    return table
end

end # module TableMetadataTools
