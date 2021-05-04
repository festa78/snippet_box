$data=Get-Content dist/js/vendor.js | % { $_ -replace "￿","" }
$data | Out-File dist/js/vendor.js -Encoding UTF8