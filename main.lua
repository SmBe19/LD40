local utf8 = require("utf8")
local http = require("socket.http")
local httpurl = require("socket.url")

function love.load()
  g = {}
  g.alive = true -- whether the player is alive
  g.money = 0 -- current money amount
  g.loan = 0 -- total loans taken
  g.time = 0 -- current time since start in seconds
  g.billrate = 10 -- a new bill arrives each x seconds
  g.billratemin = 4
  g.billrateincrease = 0.95 -- multiplier for billrate
  g.billamountmax = 1000 -- max amount of a bill
  g.billamountmin = 100 -- min amount of a bill
  g.billamountincrease = 1.07 -- multiplier for bill amount
  g.billduemin = 2 -- min time for bill due duration in days
  g.billduemax = 7 -- max time for bill due duration in days
  g.lastbill = -g.billrate -- time of the last bill
  g.loanamount = 1000 -- amount per loan taken
  g.loanincrease = 1.05 -- multiplier for loan amount
  g.loanrate = 70 -- time after which interest of a loan is owed
  g.interestmin = 0.05 -- minimal interest
  g.interestmax = 0.3 -- maximal interest
  g.interestdur1 = 42 -- sin 1 for interest progression
  g.interestdur2 = math.pi * 2 -- sin 2 for interest progression
  g.noticeincrease = 1.5 -- percentage added if due date is missed
  g.notpaidincrease = 2 -- percentage added if not paid
  g.dayduration = 7 -- duration of day in seconds
  g.activebill = nil -- currently selected bill
  g.loandialogopen = false -- whether a dialog for a loan is currently open
  g.username = "" -- current username
  g.usernameallowed = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_ " -- allowed chars in usernames
  g.loans = {} -- list of all loans
  g.bills = {} -- list of all bills
  g.dialog = {} -- list of all dialogs
  g.highscore = {} -- online highscore
  g.highscoreserver = "http://ludumdare.games.smeanox.com/LD40/highserver" -- path of highscore server

  reset()

  g.compname = {}
  g.compname[1] = {"Alphabet", "Fruity", "Space", "Ludum", "Giant", "Mike", "Nikola", "Lazy", "Fast", "Happy", "M$", "Electronic", "Sealed", "X"}
  g.compname[2] = {"Bear", "X", "Systems", "Dare", "Turtle", "Power", "Tesla", "Snail", "Jam", "Honey", "Times", "Arts", "Valve", "Apple", "Banana", "Orange", "COM", "Energy", "Air"}
  g.compname[3] = {"Inc", "Ltd", "Co", "Corp", "& Sons", "& Daughters", "Co Inc"}
  g.bankname = {}
  g.bankname[1] = {"Credit Suisse", "America", "USB", "Matteo's", "Ben's", "China", "Mexico", "Canada"}
  g.bankname[2] = {"Inc", "Ltd", "Co", "Financial", "Trust"}

  g.months = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
  g.monthname = {"Jan", "Feb", "Mar", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dez"}
  g.suffixes = {"st", "nd", "rd", "th"}

  g.okText = {"OK", "Ok", "kk", "OK!", "Whatever", "Hmm", "k", "Kthxbai"}
  g.yesText = {"Yes", "Yess", "Ya", "Yeah"}
  g.noText = {"No", "Noo", "Na", "Nope", "nope"}

  img = {}
  img.bg = love.graphics.newImage("data/bg.png")
  img.notice = love.graphics.newImage("data/notice_stamp.png")
  img.noticelarge = love.graphics.newImage("data/notice_stamp_large.png")
  img.money = love.graphics.newImage("data/money.png")
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
  g.billamountmax = 1000
  g.billamountmin = 100
  g.loanamount = 1000
  g.lastbill = -g.billrate
  g.bills = {}
  g.loans = {}
  g.dialogs = {}
  g.activebill = nil
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
  newbill.amount = math.ceil(amount or love.math.random(g.billamountmin, g.billamountmax))
  newbill.time = math.ceil(g.time / g.dayduration) * g.dayduration
  newbill.due = love.math.random(g.billduemin, g.billduemax) * g.dayduration
  newbill.notice = not not notice
  newbill.title = title or getCompanyName()
  newbill.opened = false
  newbill.paid = false
  newbill.color = {love.math.random(150, 255), love.math.random(150, 255), love.math.random(150, 255)}
  newbill.offx = love.math.random(-15, 15)
  newbill.offy = love.math.random(-5, 5)
  newbill.rotation = (love.math.random() - 0.5) * math.pi / 8
  newbill.noticerotation = (love.math.random() - 0.5) * math.pi / 2
  newbill.noticeoffx = love.math.random(-45, 45)
  newbill.noticeoffy = love.math.random(-10, 10)
  newbill.img = img.bill[love.math.random(1, #img.bill)]
  newbill.imgopen = img.billopened[love.math.random(1, #img.billopened)]
  newbill.imgletter = img.letter[love.math.random(1, #img.letter)]
  newbill.dialogopen = false
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
    if not self.paid then
      if g.money >= self.amount then
        g.money = g.money - self.amount
        self.paid = true
        if self == g.activebill then
          g.activebill = nil
        end
      end
    end
  end

  local found = false
  for idx, bill in ipairs(g.bills) do
    if bill.paid then
      g.bills[idx] = newbill
      found = true
      break
    end
  end
  if not found then
    g.bills[#g.bills+1] = newbill
  end
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
  newloan.rotation = (love.math.random() - 0.5) * math.pi / 8
  newloan.img = img.loan[love.math.random(1, #img.loan)]
  function newloan.draw(self)
    love.graphics.draw(self.img, self.offx, self.offy, self.rotation)
  end
  g.money = g.money + newloan.amount
  g.loan = g.loan + newloan.amount

  g.loans[#g.loans+1] = newloan
end

function newButton(text, x, y, onclick)
  local newbutton = {}
  newbutton.text = text
  newbutton.onclick = onclick
  newbutton.x = x or 0
  newbutton.y = y or 0
  function newbutton.draw(self)
    love.graphics.print(self.text, self.x, self.y)
  end
  return newbutton
end

function newDialog(text, buttons)
  local newdialog = {}
  local width = 200
  local height = 200
  newdialog.text = text
  newdialog.buttons = buttons
  newdialog.x = love.math.random(0, 800 - width)
  newdialog.y = love.math.random(0, 600 - height)
  newdialog.width = width
  newdialog.height = height
  function newdialog.draw(self)
    love.graphics.origin()
    love.graphics.translate(self.x, self.y)
    love.graphics.print(self.text, 10, 10)
    for idx, button in ipairs(self.buttons) do
      button:draw()
    end
  end
  function newdialog.close(self)
    local index = nil
    for idx, dia in ipairs(g.dialogs) do
      if dia == self then
        index = idx
      end
    end
    if index then
      table.remove(g.dialogs, index)
    end
  end
  function newdialog.checkclick(self, x, y)
    if self.x < x and x < self.x + self.width and self.y < y and y < self.y + self.height then
      for idx, button in ipairs(self.buttons) do
        if self.x + button.x < x and x < self.x + button.x + 50 and self.y + button.y < y and y < self.y + button.y + 20 then
          if button.onclick then
            button:onclick(self)
          end
          self:close()
          return True
        end
      end
    end
    return False
  end

  g.dialogs[#g.dialogs+1] = newdialog
end

function submitHighscore()
  local score = math.floor(g.time)
  local magic = score % 17 * g.username:len() + math.floor(score / 17)
  local niceusername = httpurl.escape(g.username)
  body, code = http.request(g.highscoreserver .. "/submit.php?username=" .. niceusername .. "&score=" .. math.floor(g.time) .. "&magic=" .. magic)
end

function updateHighscore()
  local score = math.floor(g.time)
  body, code = http.request(g.highscoreserver .. "/get.php?format=lua")
  if code == 200 then
    local idx = 1
    local nxt
    local found = false
    g.highscore = {}
    for line in body:gmatch("[^\n]+") do
      if idx % 2 == 1 then
        nxt = {line}
      else
        nxt[2] = line
        if score >= tonumber(line) then
          g.highscore[#g.highscore+1] = {"You", score}
          found = true
        end
        g.highscore[#g.highscore+1] = nxt
      end
      idx = idx + 1
    end
    if not found then
      g.highscore[#g.highscore+1] = {"You", score}
    end
  end
end

function love.update(dt)
  if g.alive then
    g.time = g.time + dt
    if g.time - g.lastbill > g.billrate then
      newBill()
      g.lastbill = g.time
      g.billrate = math.max(g.billrate * g.billrateincrease, g.billratemin)
      g.loanamount = math.ceil(g.loanamount * g.loanincrease)
      g.billamountmax = math.ceil(g.billamountmax * g.billamountincrease)
    end
    for idx, loan in ipairs(g.loans) do
      if g.time - loan.lastinterest > g.loanrate then
        newBill(loan.amount * loan.interest, loan.title)
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
              if bill == g.activebill then
                g.activebill = nil
              end
              newDialog("You did not pay your bill.\n" .. bill.title .. " took their money themselves.", {
                newButton(g.okText[love.math.random(1, #g.yesText)], 80, 80)
              })
            else
              g.alive = false
              g.activebill = bill
              updateHighscore()
            end
          else
            bill.paid = true
            if bill == g.activebill then
              g.activebill = nil
            end
            newBill(bill.amount * g.noticeincrease, bill.title, true)
          end
        end
      end
    end
  end
end

function handleDialogClick(x, y)
  for idx, dialog in ipairs(g.dialogs) do
    if dialog:checkclick(x, y) then
      return true
    end
  end
  return false
end

function love.mousereleased(x, y, button, istouch)
  if 500 < x and x < 800 and 0 < y and y < 70 then
    if not g.loandialogopen then
      if love.math.random(1, 8) == 2 then
        g.loandialogopen = true
        newDialog("Do you really want to take a loan?", {
          newButton(g.yesText[love.math.random(1, #g.yesText)], 80, 80, function(self, dialog) g.loandialogopen = false; newLoan() end),
          newButton(g.noText[love.math.random(1, #g.noText)], 150, 80, function(self, dialog) g.loandialogopen = false end)
        })
      else
        newLoan()
      end
    end
  elseif g.activebill and 300 < x and x < 500 and 410 < y and y < 450 then
    if g.activebill.amount <= g.money then
      if not g.activebill.dialogopen then
        if love.math.random(1, 8) == 2 then
          local bill = g.activebill
          bill.dialogopen = true
          newDialog("Do you really want to pay $" .. g.activebill.amount .. " to " .. g.activebill.title .. "?", {
            newButton(g.yesText[love.math.random(1, #g.yesText)], 80, 80, function(self, dialog) bill:onpay(); bill.dialogopen = false end),
            newButton(g.noText[love.math.random(1, #g.noText)],150, 80, function(self, dialog) bill.dialogopen = false end)
          })
        else
          g.activebill:onpay()
        end
      end
    else
      newDialog("You don't have enough money.\nMaybe you should take a loan.", {
        newButton(g.okText[love.math.random(1, #g.yesText)], 80, 80)
      })
    end
  elseif handleDialogClick(x, y) then
    -- do nothing
  else
    local clickedbill = nil
    local ax = 20
    local ay = 50
    for idx, bill in ipairs(g.bills) do
      if not bill.paid then
        if ax + bill.offx < x and x < ax + bill.offx + 80 and ay + bill.offy < y and y < ay  + bill.offy + 50 then
          clickedbill = bill
        end
      end
      ay = ay + 25
      if idx % 20 == 0 then
        ax = ax + 40
        ay = ay - 25*20
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
    if g.usernameallowed:find(t) then
      g.username = g.username .. t
    end
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
  -- background
  love.graphics.setFont(img.fontnormal)
  love.graphics.setColor(255, 255, 255)
  love.graphics.origin()
  love.graphics.draw(img.bg, 0, 0)

  if g.alive then
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

    for idx, bill in ipairs(g.bills) do
      if not bill.paid then
        bill:draw()
      end
      love.graphics.translate(0, 25)
      if idx % 20 == 0 then
        love.graphics.translate(40, -25*20)
      end
    end

    if g.activebill then
      love.graphics.setColor(g.activebill.color)
      love.graphics.setFont(img.fontnormal)
      love.graphics.origin()
      love.graphics.translate(300, 80)
      love.graphics.draw(g.activebill.imgletter)
      if g.activebill.notice then
        love.graphics.draw(img.noticelarge, 100 + g.activebill.noticeoffx, 50 + g.activebill.noticeoffy, g.activebill.noticerotation)
      end
      love.graphics.setColor(20, 20, 20)
      love.graphics.print(g.activebill.title, 10, 10)
      local text = "Due " .. getDayName(g.activebill.time + g.activebill.due)
      love.graphics.print(text, 100 - img.fontnormal:getWidth(text)/2, 190)
      love.graphics.setFont(img.fontlarge)
      love.graphics.print("$" .. g.activebill.amount, 115, 245)
      text = "Pay bill"
      love.graphics.print("Pay bill", 100 - img.fontlarge:getWidth(text) / 2, 340)
    end

    -- UI
    -- Calendar
    local text = ""
    local monthday = getMonthDay(g.time)
    love.graphics.setColor(255, 255, 255)
    love.graphics.origin()
    love.graphics.translate(350, 460)
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

    -- Money
    text = "$ " .. g.money
    love.graphics.setColor(255, 255, 255)
    love.graphics.origin()
    love.graphics.draw(img.money, 320, 20)
    love.graphics.setFont(img.fontlarge)
    love.graphics.translate(400 - img.fontlarge:getWidth(text) / 2, 30)
    love.graphics.print(text)

    -- Loan
    text = "Get $" .. g.loanamount .. " Loan (" .. (currentInterest() * 100) .. "%)"
    love.graphics.origin()
    love.graphics.setFont(img.fontlarge)
    love.graphics.translate(750 - img.fontlarge:getWidth(text), 30)
    love.graphics.print(text)

    -- Dialogs
    love.graphics.setColor(255, 255, 255)
    love.graphics.origin()
    for idx, dialog in ipairs(g.dialogs) do
      dialog:draw()
    end
  else
    -- Money
    text = "$ " .. g.money
    love.graphics.setColor(255, 255, 255)
    love.graphics.origin()
    love.graphics.draw(img.money, 320, 20)
    love.graphics.setFont(img.fontlarge)
    love.graphics.translate(400 - img.fontlarge:getWidth(text) / 2, 30)
    love.graphics.print(text)

    love.graphics.setFont(img.fontnormal)

    love.graphics.origin()
    love.graphics.translate(150, 150)
    love.graphics.print("The bill of " .. g.activebill.title .. " bankrupted you!")
    love.graphics.translate(0, 20)
    love.graphics.print("Score: " .. math.floor(g.time) .. "s")
    love.graphics.translate(0, 20)
    love.graphics.print("Enter username: " .. g.username)

    love.graphics.translate(0, 40)
    for idx, high in ipairs(g.highscore) do
      if high[1] == "You" and high[2] == math.floor(g.time) then
        love.graphics.setColor(200, 0, 0)
      else
        love.graphics.setColor(255, 255, 255)
      end
      love.graphics.print(getOrdinal(idx), 0, 0)
      love.graphics.print(high[2] .. "s", 50, 0)
      love.graphics.print(high[1], 100, 0)
      love.graphics.translate(0, 20)
    end
  end
end
