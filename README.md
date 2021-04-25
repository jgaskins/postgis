# postgis

PostGIS data types and encoders/decoders for the Crystal Postgres driver.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     postgis:
       github: jgaskins/postgis
   ```

2. Run `shards install`

## Usage

Ensure that your database has the `postgis` extension enabled:

```sql
CREATE EXTENSION postgis
```

Load PostGIS into your application

```crystal
require "postgis"
```

If you're writing raw SQL queries, you can specify the type of the result:

```crystal
db.query_one "SELECT 'point(1 2 3)'::geography", as: PostGIS::Point3D
```

If you're using `DB::Serializable`, you can use `PostGIS` types for the models:

```crystal
struct Address
  include DB::Serializable

  # ...
  getter coordinates : PostGIS::Point2D
end
```

Currently supported GIS types:

| GIS Type | Crystal type |
|----------|--------------|
| `POINT`  | `PostGIS::Point2D`, `PostGIS::Point3D` |
| `POLYGON` | `PostGIS::Polygon2D` |

More will be added in the future.

## Contributing

1. Fork it (<https://github.com/jgaskins/postgis/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Jamie Gaskins](https://github.com/jgaskins) - creator and maintainer
