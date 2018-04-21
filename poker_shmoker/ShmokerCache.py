import memcache
import hashlib
import random
import time


class ShmokerCache:
    def __init__(self, calc_rate=0.1, client_ip="127.0.0.1", refresh_type="average", exp_factor=10):
        self.mc = memcache.Client([client_ip])

        # test functionality
        self.mc.set('test_key', 'test_value')
        if self.mc.get('test_key') != "test_value":
            raise Exception("Memcache __init__ failed")

        self.calc_rate = calc_rate
        self.refresh_type = refresh_type
        self.exp_factor = exp_factor

    def __call__(self, func):
        def newfn(*args, **kwargs):

            key = self.make_key(func, args, kwargs)
            value = self.mc.get(key)

            if value is not None:
                if random.random() < self.calc_rate:
                    return self.refresh_value(func, args, kwargs, key, value)
                return value[0]
            else:
                value = (func(*args, **kwargs), 1)
                self.mc.set(key, value, time=0)
                return value[0]
        return newfn

    def clear(self):
        self.mc.flush_all()
        return

    def make_key(self, func, f_args, f_kwargs):
        m = hashlib.md5()
        [m.update(x.__repr__().encode("utf-8")) for x in f_args if "object at" not in x.__repr__()]
        [m.update(x.__repr__().encode("utf-8")) for x in f_kwargs.values() if "object at" not in x.__repr__()]
        m.update(func.__name__.encode("utf-8"))
        m.update(func.__class__.__name__.encode("utf-8"))
        m.update(self.refresh_type.encode("utf-8"))

        return m.hexdigest()

    def refresh_value(self, func, args, kwargs, key, value):
        if self.refresh_type == "average":
            new_function_evaluation = func(*args, **kwargs)
            new_value = (
                (value[0]*value[1] + new_function_evaluation)/(value[1]+1),
                value[1] + 1
            )
            self.mc.set(key, new_value, time=0)
            return new_value[0]
        elif self.refresh_type == "average_exp":
            new_function_evaluation = func(*args, **kwargs)
            new_value = (
                (value[0]*(self.exp_factor-1) + new_function_evaluation)/self.exp_factor,
                value[1] + 1
            )
            self.mc.set(key, new_value, time=0)
            return new_value[0]
        raise Exception("refresh type isn't supported")
