import random
from io import BytesIO

from PIL import Image, ImageDraw, ImageFont
from django.contrib import auth
from django.contrib.auth.hashers import make_password
from django.http import JsonResponse
from django.shortcuts import render, HttpResponse
from django.utils.decorators import method_decorator
from django.views.decorators.csrf import ensure_csrf_cookie
from django.views.generic import View

from blog import models
from blog.entity import forms


class ValidImageView(View):
    # 生成图片验证码
    def get(self, request):
        # rgb
        def get_random_color():
            return random.randint(0, 255), random.randint(0, 255), random.randint(0, 255)

        img_obj = Image.new(
            'RGB',
            (200, 35),
            get_random_color()
        )
        # 在图片上写字，生成一个图片画笔对象
        draw_obj = ImageDraw.Draw(img_obj)
        # 加载字体文件，得到一个字体对象
        font_obj = ImageFont.truetype("static/font/kumo.ttf", 28)
        tmp_lst = []
        for i in range(5):
            u = chr(random.randint(65, 90))  # 生成大写字母
            l = chr(random.randint(97, 122))  # 生成小写字母
            n = str(random.randint(0, 9))  # 生成数字
            tmp = random.choice([u, l, n])
            tmp_lst.append(tmp)
            draw_obj.text((20 + 40 * i, 0), tmp, fill=get_random_color(), font=font_obj)
        request.session["valid_code"] = "".join(tmp_lst)
        io_obj = BytesIO()
        img_obj.save(io_obj, "png")
        data = io_obj.getvalue()
        # print(tmp_lst)
        return HttpResponse(data)


class UserSignInView(View):

    @method_decorator(ensure_csrf_cookie)
    def post(self, request):
        username = request.POST.get("username")
        password = request.POST.get("password")
        valid_code = request.POST.get("valid_code")
        ret = {}
        if valid_code.upper() == request.session.get("valid_code", "").upper():
            # print(username, password)
            """
            django 2.2 需要手动给密码加密，如果不加密，这里的验证过不去
            """
            user = auth.authenticate(username=username, password=password)
            # print(user)
            if user:
                auth.login(request, user)
                ret["msg"] = "/blog/article_list/"
            else:
                ret["status"] = 1
                ret["msg"] = "用户名或密码错误！"
            # return render(request, "login.html")
            return JsonResponse(ret)
        else:
            ret["status"] = 1
            ret["msg"] = "验证码错误！"
            return JsonResponse(ret)

    # @method_decorator(ensure_csrf_cookie)
    def get(self, request):
        return render(request, "login.html")


class UseSignOutView(View):
    # 前端通过ajax提交登出请求
    def post(self, request):
        auth.logout(request)
        ret = {"msg": "/index/"}
        return JsonResponse(ret)


class UserRegisterView(View):
    def post(self, request):
        ret = {}
        form_obj = forms.RegFrom(request.POST)
        # print(request.POST)
        if form_obj.is_valid():
            form_obj.cleaned_data.pop("re_password")
            # avatar 是一个文件，需要使用 FILES.get()方法
            avatar_img = request.FILES.get("avatar")
            # django 2.2 需要自己对密码进行加密，否则密码将以明文的方式存储在数据库中，在后续使用django auth验证的时候会出错
            pwd = form_obj.cleaned_data.get("password")
            form_obj.cleaned_data["password"] = make_password(pwd)

            models.UserInfo.objects.create(**form_obj.cleaned_data, avatar=avatar_img)
            ret["status"] = 0
            ret["msg"] = "/login/"
        else:
            ret["status"] = 1
            ret["msg"] = form_obj.errors
        return JsonResponse(ret)

    def get(self, request):
        form_obj = forms.RegFrom()

        return render(request, "register.html", {"form_obj": form_obj})


"""
this is four test
demo1
<<<<<<< HEAD
change1
=======
chanage2
>>>>>>> a90a524c775ca1da449d965d0dcd29b83904a6eb

change4
"""
