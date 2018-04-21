from distutils.core import setup

print("setting up")

setup(name='poker_shmoker',
      version='1.0',
      description='Poker Bot',
      author='Mikhail Kashtaev',
      author_email='kashtik.tinker16@gmail.com',
      packages=['poker_shmoker'],
      package_data={"poker_shmoker": ["array_storage/*"]},
      install_requires=['eval7']
      )

