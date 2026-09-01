import apps.catalog

var apps_list = apps.catalog.basic_apps()
var i = 0
while i < len(apps_list):
    print("App: ", apps_list[i][0])
    i = i + 1
