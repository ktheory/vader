# vader
Very Advanced Docker Environment for Rails

## Commands

Install vader: `curl get.vader.codes | bash -e`

`vader init` - configures current directory for vader

`vader sync` - starts rsync daemon, usually called by startup script

`vader sync-back` - called after `rails g`, `bundle`

`vader exec ...`

`vader up`

`vader -v`
`vader help`

# Config:
`.vader.yml`:
```
min_version: 123 # Minimum required vader version
exec_container: app
```

