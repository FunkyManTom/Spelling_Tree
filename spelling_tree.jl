using Unicode
using PyPlot
using Distributions
using DelimitedFiles
using CSV
using Tables
using ProgressBars
using Combinatorics

pygui(true)
my_lock=ReentrantLock()

function create_words(attempt=1; min_words=50)
    letters=alphabet[sample(1:26,7,replace=false)] #First letter must be part of word

    let_map=0
    for (i,v) in enumerate(alphabet)
        occursin(v,letters) ? (let_map+=2^(i-1)) : nothing #Create bit map of letters of interest
    end
    lmap=UInt32(let_map)
    smap=UInt32(2^(findfirst(letters[1], alphabet)[1]-1))
    promtlst=[]
    for i in wordlst
        if i[2]&lmap==i[2] && i[2]&smap==smap
            push!(promtlst,[i[1],i[3]])
        end #Check if word contains only letters of interest & starts with first letter
    end

    flp=0
    while flp==0
        changed=0
        for i in eachindex(promtlst)[2:end]
            if promtlst[i-1][1]==promtlst[i][1]
                promtlst=deleteat!(promtlst,i)
                changed=1
                break
            end
        end
        changed==0 ? (flp=1) : nothing
    end

    LUMatrix=Array{String}(undef,length(promtlst),3)
    for i in eachindex(promtlst)
        LUMatrix[i,1]=promtlst[i][1]
        LUMatrix[i,2]=promtlst[i][2]
        LUMatrix[i,3]="n"
    end

    #for i in promtlst
    #    println(i[1],"  ",i[2])
    #end

    if length(promtlst)<min_words
        return create_words(attempt+1,min_words=min_words)
    end

    return LUMatrix,promtlst,letters,lmap,attempt
end

function stats(iter,min_words)
    attempt_list=zeros(iter)
    num_words=zeros(iter)
    num_letter=zeros(iter)
    most_words=0
    most_words_set=""
    Threads.@threads for i in ProgressBar(1:iter)
        tmp,letter,attempt_list[i]=create_words(1,min_words=min_words)[[1,3,5]]
        num_letter[i]=findfirst(letter[1],alphabet)
        num_words[i]=length(tmp[:,1])
        if num_words[i]>most_words
            most_words=num_words[i]
            most_words_set=letter
        end
    end
    
    subplot(2,2,1)
    hist2D(num_words,attempt_list,bins=[collect(min_words:maximum(num_words)),collect(1:maximum(attempt_list))],norm="log")
    ylabel("Number of attempts")
    xlabel("Number of words")
    subplot(2,2,2)
    hist(attempt_list,collect(1:maximum(attempt_list)),color="blue",alpha=0.5,align="left")
    xlabel("Number of attempts")
    subplot(2,2,3)
    hist(num_words,collect(min_words:maximum(num_words)),color="blue",alpha=0.5,align="left")
    xlabel("Number of words")
    subplot(2,2,4)
    hist(num_letter,collect(1:26),color="blue",alpha=0.5,align="left")
    xticks(1:26,alphabet[1:26])
    show()

    println("Most words: ",most_words," with letters: ",most_words_set)
    return
end

function loop()
    println("Creating Word List:\n")
    LUMatrix,promtlst,letters,lmap,attempt=create_words()
    println();println(string(length(promtlst))*" words found!\nAttempts: ",attempt,"\n\n")

    input=""
    found_words=0
    found_lst=[]
    println("Words may only contain the letters $(uppercase(letters[2:end])) and must always contain the letter $(uppercase(letters[1])) \nTry to find all $(length(promtlst)) such words!\nType !help for commands\n")
    cmnd=0
    while input!="!exit"
        print("Enter word ($(uppercase(letters))): \n");print("> ")
        input=readline()
        if input==""
            continue
        end
        input=Unicode.normalize(lowercase(input),stripmark=true)
        in_map=0
        for (i,v) in enumerate(alphabet)
            occursin(v,input) ? (in_map+=2^(i-1)) : nothing
        end
        if length(input)<4 && input[1]!="!"
            println("\nWord must be at least 4 characters long.\n")
            continue
        end
        if !occursin(letters[1],input) && string(input[1])!="!"
            println("\nWord must contain the letter $(uppercase(letters[1])).\n")
            continue
        end
        if in_map&lmap!=in_map && string(input[1])!="!"
            println("\nWord must only contain the letters $(uppercase(letters)).\n")
            continue
        end
        if !any([input==i for i in found_lst])&& string(input[1])!="!"
            word_check=0
            for i in eachindex(LUMatrix[:,1])
                if input==LUMatrix[i,1]
                    println()
                    println(LUMatrix[i,2])
                    found_words+=1
                    word_check=1
                    push!(found_lst,LUMatrix[i,1])
                    LUMatrix[i,3]="y"
                    println("\n$found_words/"*string(length(promtlst))*" words found!\n")
                    break
                end
            end
            if word_check==0
                println("\nWord not in dictionary.\n")
            end
        else
            if string(input[1])!="!"
                println("\nWord already found.\n")
            end
        end
        if input=="!exit" #redundant but just in case
            cmnd=1
            break
        end
        if input=="!list"
            cmnd=1
            println("\n\n$found_words/"*string(length(promtlst))*" words found!\n\n")
            for i in found_lst
                println(i)
            end
            println()
        end
        if input=="!solve"
            cmnd=1
            println("\n\n$found_words/"*string(length(promtlst))*" words found!\n\n")
            println()
            for i in eachindex(LUMatrix[:,1])
                print(LUMatrix[i,1])
                if LUMatrix[i,3]=="y"
                    println("\t\t✔️")
                else
                    println()
                end
            end
            found_words=length(promtlst)
            println("\nPress any key to start new game")
            readline()
            input="!restart"
        end
        if input=="!hint"
            cmnd=1
            println("\n\n$found_words/"*string(length(promtlst))*" words found!\n\n")
            for i in eachindex(LUMatrix[:,1])
                if LUMatrix[i,3]=="n"
                    print(LUMatrix[i,1][1])
                    for j in 2:length(LUMatrix[i,1])
                        print("_")
                    end
                    println()
                else
                    println(LUMatrix[i,1])
                end
            end
            println()
        end
        if input=="!restart"
            cmnd=1
            println("Creating Word List:\n")
            LUMatrix,promtlst,letters,lmap,attempt=create_words()
            println();println(string(length(promtlst))*" words found!\nAttempts: ",attempt,"\n\n")
            found_words=0
            found_lst=[]
            println("Words may only contain the letters $(uppercase(letters[2:end])) and must always contain the letter $(uppercase(letters[1])) \nTry to find all $(length(promtlst)) such words!\nType !help for commands")
        end
        if input=="!help"
            cmnd=1
            println()
            println("Commands:")
            println("!list - List found words")
            println("!hint - Display a hint")
            println("!solve - List all possible words")
            println("!restart - Restart game with new word list")
            println("!exit - Exit program")
            println("!help - Display this message")
            println()
        end
        if occursin("!stats",input)
            cmnd=1
            stats(parse(Int,split(input," ")[2]),parse(Int,split(input," ")[3]))
        end
        if cmnd==0 && string(input[1])=="!"
            println("\nInvalid command.\n")
        end
        cmnd=0
        if found_words==length(promtlst)
            println("\nAll words found!\n")
        end
    end
end

alphabet="abcdefghijklmnopqrstuvwxyz"

if isfile("LUT.txt")
    println("Loading LUT")
    wordlst=[]
    open("LUT.txt") do f
        while ! eof(f)
            s=readline(f)
            push!(wordlst,[split(s,"\t")[1],parse(UInt32,split(s,"\t")[2]),split(s,"\t")[3]])
        end
    end
else
    println("Creating LUT")
    wordlst=[]
    wordlst_med=[]
    nums="0123456789"

    open("medium.txt") do f
        while ! eof(f)
            s=readline(f)
            if !occursin("-",s) && !occursin(".",s) && !occursin("'",s) && !occursin("/",s) && !occursin(" ",s) #Ignore words with spaces, hyphens or other symbols
                s=Unicode.normalize(lowercase(s),stripmark=true) #Remove accents
                length(s)>3 ? push!(wordlst_med,s) : nothing
            end
        end
    end

    open("scrabble_def.txt") do f
        line=0
        while ! eof(f)
            tmp=readline(f)
            if length(tmp)>2 && !occursin("-",split(tmp,"\t")[1]) && !occursin(".",split(tmp,"\t")[1]) && !occursin("'",split(tmp,"\t")[1]) && !occursin("/",split(tmp,"\t")[1]) && !occursin(" ",split(tmp,"\t")[1]) #Ignore words with spaces or hyphens
                s,def=split(tmp,"\t",limit=2) #Split word and definition
                s=Unicode.normalize(lowercase(s),stripmark=true) #Remove accents
                for i in nums
                    s=replace(s,i=>"")
                end
                line +=1
                if line%1000==0
                    println(line," words read")
                end
                if length(s)>3 && s in wordlst_med #Check if word is in word list
                    bitmp=0
                    for (i,v) in enumerate(alphabet)
                        occursin(v,s) ? bitmp+=2^(i-1) : nothing #Create bit map of letters in word
                    end
                    push!(wordlst,[s,UInt32(bitmp),def])
                end
            end
        end
    end
    println("LUT Created succesfully");println()
    println("Saving LUT")
    writedlm("LUT.txt",wordlst)
end
loop()
exit() 
### END OF PROGRAM WHEN RUNNING INTERACTIVE MODE ###

### Check all letter combinations
function letter_perm()
    curr_max=zeros(Int64,Threads.nthreads())
    pangram_max=zeros(Int64,Threads.nthreads())
    combi_list=zeros(UInt32,26*binomial(26,6),4)
    letter_comb=combinations(alphabet,6)
    optional_counter=zeros(Int64,Threads.nthreads())
    must_id=zeros(Int64,Threads.nthreads())
    save_id=1
    Threads.@threads for must in ProgressBar(alphabet)
        must_id[Threads.threadid()]=findfirst(must,alphabet)
        optional_counter[Threads.threadid()]=0
        for optional in collect(letter_comb)
            if !occursin(must,String(optional))
                optional_counter[Threads.threadid()]+=1
                letters=must*String(optional)

                let_map=0
                for (i,v) in enumerate(alphabet)
                    occursin(v,letters) ? (let_map+=2^(i-1)) : nothing #Create bit map of letters of interest
                end
                lmap=UInt32(let_map)
                smap=UInt32(2^(findfirst(letters[1], alphabet)[1]-1))
                promtlst=[]
                for i in wordlst
                    if i[2]&lmap==i[2] && i[2]&smap==smap
                        push!(promtlst,[i[1],i[2]])
                    end #Check if word contains only letters of interest & starts with first letter
                end

                flp=0
                while flp==0
                    changed=0
                    for i in eachindex(promtlst)[2:end]
                        if promtlst[i-1][1]==promtlst[i][1]
                            deleteat!(promtlst,i)
                            changed=1
                            break
                        end
                    end
                    changed==0 ? (flp=1) : nothing
                end

                pangram=0
                for i in eachindex(promtlst)
                    if promtlst[i][2]==lmap
                        pangram+=1
                    end
                end

                @lock my_lock combi_list[(must_id[Threads.threadid()]-1)*binomial(26,6)+optional_counter[Threads.threadid()],:]=[findfirst(letters[1],alphabet),lmap-smap,length(promtlst),pangram] #Store first letter, bit map and number of words
                if length(promtlst)>maximum(curr_max)
                    @lock my_lock curr_max[Threads.threadid()]=length(promtlst)
                    print("New max wordcount: ",maximum(curr_max)," with letters: ",letters,"\n")
                end
                if pangram>maximum(pangram_max)
                    print("New max pangram: ",pangram," with letters: ",letters,"\n")
                    @lock my_lock pangram_max[Threads.threadid()]=pangram
                end
            end
        end
    end
    return combi_list
end

combi_list=letter_perm()
combi_list_remove=combi_list[combi_list[:,1].!=0,:]

CSV.write("combi.csv",Tables.table(combi_list_remove),header=["First letter","Bit map","Number of words","Number of pangrams"])

combi_hr=[]
for i in eachindex(combi_list_remove[:,1])
    rec=alphabet[combi_list_remove[i,1]]
    for (id,bit_val) in enumerate(digits(combi_list_remove[i,2],base=2,pad=26))
        if Bool(bit_val)
            rec*=alphabet[id]
        end
    end
    push!(combi_hr,[rec,Int64(combi_list_remove[i,3])])
end
combi_hr=reduce(hcat,combi_hr)
combi_hr=permutedims(combi_hr[:,sortperm(combi_hr[2,:])] |> reverse)

hist(combi_hr[:,1],collect(minimum(combi_hr[:,1]):maximum(combi_hr[:,1])),color="blue",alpha=0.5,align="left",log=true)
xlabel("Number of words")

hist2D(combi_list_remove[:,3],combi_list_remove[:,1],bins=[collect(0:1+maximum(combi_list_remove[:,3])),collect(1:27)],norm="log")
yticks(1.5:26.5,alphabet[1:26])
xlabel("Number of words")
ylabel("First letter")
#savefig("letter_comb_$save_id.png",dpi=300)

hist2D(combi_list_remove[:,3],combi_list_remove[:,4],bins=[collect(0:1+maximum(combi_list_remove[:,3])),collect(0:1+maximum(combi_list_remove[:,4]))],norm="log")
xlabel("Number of words")
ylabel("Number of pangrams")
yticks(0.5:maximum(combi_list_remove[:,4])+0.5,0:maximum(combi_list_remove[:,4]))

hist2D(combi_list_remove[:,4],combi_list_remove[:,1],bins=[collect(0:1+maximum(combi_list_remove[:,4])),collect(1:27)],norm="log")
xlabel("Number of pangrams")
ylabel("First letter")
yticks(1.5:26.5,alphabet[1:26])
xticks(0.5:maximum(combi_list_remove[:,4])+0.5,0:maximum(combi_list_remove[:,4]))
