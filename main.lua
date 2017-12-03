local utf8 = require("utf8")

function love.load()
  g = {}
  g.alive = true -- whether the player is alive
  g.money = 0 -- current money amount
  g.loan = 0 -- total loans taken
  g.time = 0 -- current time since start in seconds
  g.billrate = 10 -- a new bill arrives each x seconds
  g.billamount = 500 -- max amount of a bill
  g.billdue = 7 -- max time for bill due duration in days
  g.lastbill = -g.billrate -- time of the last bill
  g.loanamount = 1000 -- amount per loan taken
  g.loanrate = 70 -- time after which interest of a loan is owed
  g.interestmin = 0.05 -- minimal interest
  g.interestmax = 0.2 -- maximal interest
  g.interestdur1 = 21 -- sin 1 for interest progression
  g.interestdur2 = math.pi -- sin 2 for interest progression
  g.noticeincrease = 0.1 -- percentage added if due date is missed
  g.notpaidincrease = 1 -- percentage added if not paid
  g.dayduration = 10 -- duration of day in seconds
  g.activebill = nil -- currently selected bill
  g.username = "" -- current username
  g.loans = {} -- list of all loans
  g.bills = {} -- list of all bills

  reset()

  g.compname = {}
  g.compname[1] = {"Fruity", "Space", "Ludum", "Mike", "Nikola", "Lazy"}
  g.compname[2] = {"Bear", "X", "Dare", "Turtle", "Tesla"}
  g.compname[3] = {"Inc", "Ltd", "Electric", "Co", "Corp", "& Sons"}
  g.bankname = {}
  g.bankname[1] = {"Credit Suisse", "Bank of America", "UBS", "Matteo's Credit", "China Financial"}
  g.bankname[2] = {"Inc", "Ltd", "Co", "Corp", "& Sons"}

  g.months = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
  g.monthname = {"Jan", "Feb", "Mar", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dez"}
  g.suffixes = {"st", "nd", "rd", "th"}


  img = {}
  img.bg = love.graphics.newImage("data/bg.png")
  img.notice = love.graphics.newImage("data/notice_stamp.png")
  img.calendar = love.graphics.newImage("data/calendar.png")
  img.bill = {}
  for i = 1, 1 do
    img.bill[#img.bill + 1] = love.graphics.newImage("data/bill" .. i .. ".png")
  end
  img.billopened = {}
  for i = 1, 1 do
    img.billopened[#img.billopened + 1] = love.graphics.newImage("data/bill_opened" .. i .. ".png")
  end
  img.loan = {}
  for i = 1, 1 do
    img.loan[#img.loan + 1] = love.graphics.newImage("data/loan" .. i .. ".png")
  end
  img.letter = {}
  for i = 1, 1 do
    img.letter[#img.letter + 1] = love.graphics.newImage("data/letter_paper" .. i .. ".png")
  end
  img.fontnormal = love.graphics.newFont(12)
  img.fontlarge = love.graphics.newFont(20)
  img.fonthuge = love.graphics.newFont(42)
end

function reset()
  g.alive = true
  g.time = 0
  g.money = 0
  g.loan = 0
  g.billrate = 10
  g.lastbill = -g.billrate
  g.bills = {}
  g.loans = {}
end

function getRandomName(t)
  local name = ""
  for idx, ta in ipairs(t) do
    if idx > 1 then
      name = name .. " "
    end
    name = name .. ta[love.math.random(#ta)]
  end
  return name
end

function getCompanyName()
  return getRandomName(g.compname)
end

function getBankName()
  return getRandomName(g.bankname)
end

function getMonthDay(t)
  local day = math.ceil(t / g.dayduration) % 365
  local sol = {1, day}
  while sol[2] > g.months[sol[1]] do
    sol[2] = sol[2] - g.months[sol[1]]
    sol[1] = sol[1] + 1
  end
  return sol
end

function getOrdinal(i)
  local ii = i
  if ii > 20 then
    ii = ii % 10
  end
  if ii > 4 then
    return i .. g.suffixes[4]
  else
    return i .. g.suffixes[ii]
  end
end

function getDayName(t)
  local monthday = getMonthDay(t)
  return g.monthname[monthday[1]] .. " " .. getOrdinal(monthday[2])
end

function newBill(amount, title, notice)
  local newbill = {}
  newbill.amount = amount or math.floor(love.math.random() * g.billamount / 2 + g.billamount / 2)
  newbill.time = math.ceil(g.time / g.dayduration) * g.dayduration
  newbill.due = math.floor(love.math.random() * g.billdue / 2 + g.billdue / 2) * g.dayduration
  newbill.notice = not not notice
  newbill.title = title or getCompanyName()
  newbill.opened = false
  newbill.paid = false
  newbill.color = {love.math.random(150, 255), love.math.random(150, 255), love.math.random(150, 255)}
  newbill.offx = love.math.random(-15, 15)
  newbill.offy = love.math.random(-5, 5)
  newbill.rotation = (love.math.random() - 0.5) * math.pi / 8
  newbill.img = img.bill[love.math.random(1, #img.bill)]
  newbill.imgopen = img.billopened[love.math.random(1, #img.billopened)]
  newbill.imgletter = img.letter[love.math.random(1, #img.letter)]
  function newbill.draw(self)
    love.graphics.setColor(self.color)
    if self.opened then
      love.graphics.draw(self.imgopen, self.offx, self.offy, self.rotation)
    else
      love.graphics.draw(self.img, self.offx, self.offy, self.rotation)
    end
    if self.notice then
      love.graphics.draw(img.notice, self.offx, self.offy, self.rotation)
    end
  end
  function newbill.onpay(self)
    if g.money >= self.amount then
      g.money = g.money - self.amount
      self.paid = true
    end
  end
  g.bills[#g.bills+1] = newbill
end

function currentInterest()
  local sin1 = (math.sin(g.time / g.interestdur1 * math.pi * 2) + 1) / 2
  local sin2 = (math.sin(g.time / g.interestdur2 * math.pi * 2) + 1) / 2 / 10
  local minmax = g.interestmax - g.interestmin
  return math.floor(((sin1 + sin2) * minmax + g.interestmin) * 100) / 100
end

function newLoan()
  local newloan = {}
  newloan.amount = g.loanamount
  newloan.interest = currentInterest()
  newloan.starttime = g.time
  newloan.lastinterest = g.time
  newloan.title = getBankName()
  newloan.offx = love.math.random(-2, 2)
  newloan.offy = love.math.random(-2, 2)
  newloan.img = img.loan[love.math.random(1, #img.loan)]
  function newloan.draw(self)
    love.graphics.draw(self.img, self.offx, self.offy)
  end
  g.money = g.money + newloan.amount
  g.loan = g.loan + newloan.amount

  g.loans[#g.loans+1] = newloan
end

function submitHighscore()
end

function love.update(dt)
  if g.alive then
    g.time = g.time + dt
    if g.time - g.lastbill > g.billrate then
      newBill()
      g.lastbill = g.time
      g.billrate = g.billrate * 0.99
    end
    for idx, loan in ipairs(g.loans) do
      if g.time - loan.lastinterest > g.loanrate then
        newBill(loan.amount * loan.interest, loan.title .. " Interest")
        loan.lastinterest = g.time
      end
    end
    for idx, bill in ipairs(g.bills) do
      if not bill.paid then
        if g.time - bill.time > bill.due then
          if bill.notice then
            g.money = g.money - bill.amount * g.notpaidincrease
            if g.money >= bill.amount * g.notpaidincrease then
              bill.paid = true
            else
              g.alive = false
            end
          else
            bill.paid = true
            newBill(bill.amount, bill.title, bill.amount + bill.amount * g.noticeincrease)
          end
        end
      end
    end
  end
end

function love.mousereleased(x, y, button, istouch)
  if 500 < x and x < 800 and 0 < y and y < 70 then
    newLoan()
  else
    local clickedbill = nil
    local ax = 20
    local ay = 50
    local drawnum = 1
    for idx, bill in ipairs(g.bills) do
      if not bill.paid then
        if ax + bill.offx < x and x < ax + bill.offx + 80 and ay + bill.offy < y and y < ay  + bill.offy + 50 then
          clickedbill = bill
        end
        ay = ay + 25
        if drawnum % 20 == 0 then
          ax = ax + 40
          ay = ay - 25*20
        end
        drawnum = drawnum + 1
      end
    end
    if clickedbill then
      g.activebill = clickedbill
      g.activebill.opened = true
    end
  end
end

function love.textinput(t)
  if not g.alive then
    g.username = g.username .. t
  end
end

function love.keypressed(key)
  if not g.alive then
    if key == "backspace" then
      local byteoffset = utf8.offset(g.username, -1)
      if byteoffset then
        -- remove the last UTF-8 character.
        -- string.sub operates on bytes rather than UTF-8 characters, so we couldn't do string.sub(text, 1, -2).
        g.username = string.sub(g.username, 1, byteoffset - 1)
      end
    end
    if key == "return" then
      submitHighscore()
      reset()
    end
    if key == "escape" then
      reset()
    end
  end
end

function love.draw()
  if g.alive then
    -- background
    love.graphics.setFont(img.fontnormal)
    love.graphics.setColor(255, 255, 255)
    love.graphics.origin()
    love.graphics.draw(img.bg, 0, 0)

    -- loans
    love.graphics.setColor(255, 255, 255)
    love.graphics.origin()
    love.graphics.translate(700, 75)

    for idx, loan in ipairs(g.loans) do
      loan:draw()
      love.graphics.translate(0, 25)
      if idx % 19 == 0 then
        love.graphics.translate(-40, -25*19)
      end
    end

    -- bills
    love.graphics.setColor(255, 255, 255)
    love.graphics.origin()
    love.graphics.translate(20, 20)

    local drawnum = 1
    for idx, bill in ipairs(g.bills) do
      if not bill.paid then
        bill:draw()
        love.graphics.translate(0, 25)
        if drawnum % 20 == 0 then
          love.graphics.translate(40, -25*20)
        end
        drawnum = drawnum + 1
      end
    end

    if g.activebill then
      love.graphics.setColor(g.activebill.color)
      love.graphics.setFont(img.fontnormal)
      love.graphics.origin()
      love.graphics.translate(300, 80)
      love.graphics.draw(g.activebill.imgletter)
      if g.activebill.notice then
        love.graphics.draw(img.notice, 150, -25)
      end
      love.graphics.setColor(20, 20, 20)
      love.graphics.print(g.activebill.title, 10, 10)
      local text = "Due " .. getDayName(g.activebill.time + g.activebill.due)
      love.graphics.print(text, 100 - img.fontnormal:getWidth(text)/2, 190)
      love.graphics.setFont(img.fontlarge)
      love.graphics.print("$" .. g.activebill.amount, 115, 245)
    end

    -- UI
    local text = ""
    local monthday = getMonthDay(g.time)
    love.graphics.setColor(255, 255, 255)
    love.graphics.origin()
    love.graphics.translate(350, 440)
    love.graphics.draw(img.calendar)
    love.graphics.setFont(img.fonthuge)
    love.graphics.push()
    love.graphics.translate(50 - img.fonthuge:getWidth(monthday[2]) / 2, 25)
    love.graphics.setColor(200, 0, 0)
    love.graphics.print(monthday[2])
    love.graphics.pop()
    text = g.monthname[monthday[1]]
    love.graphics.setFont(img.fontnormal)
    love.graphics.setColor(20, 20, 20)
    love.graphics.translate(50 - img.fontnormal:getWidth(text)/2, 75)
    love.graphics.print(text)

    text = "$ " .. g.money
    love.graphics.setColor(255, 255, 255)
    love.graphics.origin()
    love.graphics.translate(400 - img.fontlarge:getWidth(text) / 2, 30)
    love.graphics.setFont(img.fontlarge)
    love.graphics.print(text)
    text = "Get $1000 loan (" .. (currentInterest() * 100) .. "%)"
    love.graphics.origin()
    love.graphics.translate(750 - img.fontlarge:getWidth(text), 30)
    love.graphics.print(text)
  else
    -- background
    love.graphics.setFont(img.fontnormal)
    love.graphics.setColor(255, 255, 255)
    love.graphics.origin()
    love.graphics.draw(img.bg, 0, 0)

    love.graphics.translate(50, 50)
    love.graphics.print("Score: " .. g.time .. " s")
    love.graphics.translate(0, 20)
    love.graphics.print("Enter username: " .. g.username)
  end
end
