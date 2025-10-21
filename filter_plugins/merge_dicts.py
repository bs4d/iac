def merge_dicts(dict_a, dict_b):
    for key in dict_b:
        # merge subdicts recursively
        if key in dict_a and isinstance(dict_a[key], dict) and isinstance(dict_b[key], dict):
            dict_a[key] = merge_dicts(dict_a[key], dict_b[key])
        # merge lists (removing duplicates + keeping the order for easier debugging)
        elif key in dict_a and isinstance(dict_a[key], list) and isinstance(dict_b[key], list):
            dict_a[key] = list(dict.fromkeys(dict_a[key] + dict_b[key]))
        # add new items / overwrite scalars
        else:
            dict_a[key] = dict_b[key]
    return dict_a

class FilterModule(object):
    def filters(self):
        return { 'merge_dicts': merge_dicts }
