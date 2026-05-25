from jinja2 import Environment, FileSystemLoader

class PromptAssembler:
    def __init__(self, template_dir):
        self.env = Environment(loader=FileSystemLoader(template_dir))

    def montar(self, template_name, **kwargs):
        template = self.env.get_template(template_name)
        return template.render(**kwargs)